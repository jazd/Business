SET search_path TO Business,"$user",public;

CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF word_value IS NOT NULL THEN
  INSERT INTO Word (value, culture) (
   SELECT word_value, Culture.code
   FROM Culture
   LEFT JOIN Word AS exists ON UPPER(exists.value) = UPPER(word_value)
    AND exists.culture = Culture.code
   WHERE UPPER(Culture.name) = UPPER(culture_name)
    AND exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Word
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Word.value) = UPPER(word_value)
   AND Word.culture = Culture.code
 );
END;
$$ LANGUAGE plpgsql;

-- Default to en-US
-- TODO: set a system wide default culture
CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT GetWord(word_value, 'en-US') AS id
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetLocation (
 lat float,
 long float,
 accuracy_code integer
) RETURNS integer AS $$
DECLARE
 inLatitude NUMERIC(10,7);
 inLongitude NUMERIC(11,7);
BEGIN
 inLatitude := lat;
 inLongitude := long;

 IF lat IS NOT NULL AND long IS NOT NULL THEN
  INSERT INTO Location (latitude, longitude, accuracy) (
   SELECT inLatitude, inLongitude, accuracy
   FROM Dual
   LEFT JOIN Location AS exists ON exists.latitude = inLatitude
    AND exists.longitude = inLongitude
    AND ((exists.accuracy = accuracy_code) OR (exists.accuracy IS NULL AND accuracy_code IS NULL))
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Location
  WHERE parent IS NULL
   AND marquee IS NULL
   AND longitude = inLongitude
   AND latitude = inLatitude
   AND ((accuracy = accuracy_code) OR (accuracy IS NULL AND accuracy_code IS NULL))
   AND level = 1 -- Default level
   AND altitudeabovesealevel IS NULL
   AND area IS NULL
 );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetPostal (
 countrycode varchar,
 zipcode varchar,
 city varchar,
 statecode varchar,
 state varchar,
 county varchar,
 lat float,
 long float,
 accuracy integer
) RETURNS integer AS $$
DECLARE
 countrycode_id integer;
 city_id integer;
 statecode_id integer;
 state_id integer;
 county_id integer;
 location_id integer;
BEGIN
 countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(countrycode));
 city_id := (SELECT GetWord(city));
 statecode_id := (SELECT GetWord(statecode));
 state_id := (SELECT GetWord(state));
 county_id := GetWord(county);
 location_id := (SELECT GetLocation(lat,long,accuracy));

 INSERT INTO Postal (country, code, state, stateabbreviation, county, city, location) (
  SELECT countrycode_id, zipcode, state_id, statecode_id, county_id, city_id, location_id
  FROM Dual
  LEFT JOIN Postal AS exists ON exists.country = countrycode_id
   AND UPPER(exists.code) = UPPER(zipcode)
  WHERE exists.id IS NULL
 );
 RETURN (
  SELECT id
  FROM Postal
  -- Unique on country and code
  WHERE country = countrycode_id
   AND UPPER(Postal.code) = UPPER(zipcode)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPostal (
 countrycode varchar,
 zipcode varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 -- Do not insert unless we have all the non-nullable fields
 -- Unique on country and code
 RETURN (
  SELECT Postal.id
  FROM Postal
  JOIN Country ON UPPER(Country.code) = UPPER(countrycode)
  WHERE Postal.country = Country.id
   AND UPPER(Postal.code) = UPPER(zipcode)
 );
END;
$$ LANGUAGE plpgsql;

-- Default to USA
CREATE OR REPLACE FUNCTION GetPostal (
 zipcode varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 -- Do not insert unless we have all the non-nullable fields
 -- Unique on country and code
 RETURN (
  SELECT Postal.id
  FROM Postal
  JOIN Country ON UPPER(Country.code) = 'USA'
  WHERE Postal.country = Country.id
   AND UPPER(Postal.code) = UPPER(zipcode)
 );
END;
$$ LANGUAGE plpgsql;

-- Default to USA
CREATE OR REPLACE FUNCTION GetAddress (
 street varchar,
 zipcode varchar,
 inPostalplus varchar(4),
 lat float,
 long float,
 inAccuracy integer
) RETURNS integer AS $$
DECLARE
 location_id integer;
 zipcode_id integer;
BEGIN
  location_id := (SELECT GetLocation(lat,long,inAccuracy));
  zipcode_id := (SELECT GetPostal(zipcode));

  IF zipcode_id IS NOT NULL THEN
   IF location_id IS NOT NULL THEN
    -- Attempt update location of existing address
    UPDATE Address
    SET location = location_id
    WHERE location IS NULL
     AND postal = zipcode_id
     AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
     AND UPPER(line1) = UPPER(street)
     AND line2 IS NULL
     AND line3 IS NULL
     AND line4 IS NULL
    ;
   END IF;

   INSERT INTO Address (line1, postal, postalplus, location) (
    SELECT street, zipcode_id, inPostalplus, location_id
    FROM Dual
    LEFT JOIN Address AS exists ON exists.postal = zipcode_id
     AND ((exists.postalplus = inPostalplus) OR (exists.postalplus IS NULL AND inPostalplus IS NULL))
     AND ((exists.location = location_id) OR (exists.location IS NULL AND location_id IS NULL))
     AND UPPER(exists.line1) = UPPER(street)
     AND exists.line2 IS NULL
     AND exists.line3 IS NULL
     AND exists.line4 IS NULL
    WHERE exists.id IS NULL
   );
  END IF;
  RETURN (
   SELECT id
   FROM Address
   WHERE postal = zipcode_id
    AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
    AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
    AND UPPER(line1) = UPPER(street)
    AND line2 IS NULL
    AND line3 IS NULL
    AND line4 IS NULL
  );
END;
$$ LANGUAGE plpgsql;

-- Default to USA
CREATE OR REPLACE FUNCTION GetAddress (
 street varchar,
 zipcode varchar,
 inPostalplus varchar(4)
) RETURNS integer AS $$
DECLARE
 zipcode_id integer;
BEGIN
  -- Do not call GetPostal with nulls so that this will return addresses with locaiton information
  zipcode_id := (SELECT GetPostal(zipcode));

  IF zipcode_id IS NOT NULL THEN
   INSERT INTO Address (line1, postal, postalplus) (
    SELECT street, zipcode_id, inPostalplus
    FROM Dual
    LEFT JOIN Address AS exists ON exists.postal = zipcode_id
     AND ((exists.postalplus = inPostalplus) OR (exists.postalplus IS NULL AND inPostalplus IS NULL))
     AND UPPER(exists.line1) = UPPER(street)
     AND exists.line2 IS NULL
     AND exists.line3 IS NULL
     AND exists.line4 IS NULL
    WHERE exists.id IS NULL
   );
  END IF;
  RETURN (
   SELECT id
   FROM Address
   WHERE postal = zipcode_id
    AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
    AND UPPER(line1) = UPPER(street)
    AND line2 IS NULL
    AND line3 IS NULL
    AND line4 IS NULL
   ORDER BY location LIMIT 1 -- pickup a location based address first
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetGiven (
 inGiven varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF inGiven IS NOT NULL THEN
  INSERT INTO Given (value) (
   SELECT inGiven
   FROM DUAL
   LEFT JOIN Given AS exists ON exists.value = inGiven
   WHERE exists.id IS NULL
  );
 END IF;

 RETURN (
  SELECT id
  FROM Given
  WHERE Given.value = inGiven
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFamily (
 inFamily varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF inFamily IS NOT NULL THEN
  INSERT INTO Family (value) (
   SELECT inFamily
   FROM DUAL
   LEFT JOIN Family AS exists ON exists.value = inFamily
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Family
  WHERE Family.value = inFamily
 ); 
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetName (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar
) RETURNS integer AS $$
DECLARE
 first_id integer;
 middle_id integer;
 last_id integer;
BEGIN
 IF inFirst IS NOT NULL OR inMiddle IS NOT NULL OR inLast IS NOT NULL THEN
  -- get given and family values
  first_id := (SELECT GetGiven(inFirst));
  middle_id := (SELECT GetGiven(inMiddle));
  last_id := (SELECT GetFamily(inLast));

  INSERT INTO Name (given, middle, family) (
   SELECT first_id, middle_id, last_id
   FROM DUAL
   LEFT JOIN Name AS exists ON
        ((exists.given = first_id) OR (exists.given IS NULL AND first_id IS NULL))
    AND ((exists.middle = middle_id) OR (exists.middle IS NULL AND middle_id IS NULL))
    AND ((exists.family = last_id) OR (exists.family IS NULL AND last_id IS NULL))
  WHERE exists.id IS NULL
  );
 END IF;

 RETURN (
  SELECT id
  FROM Name
  WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
    AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
    AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualPerson (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar,
 inBirth date,
 inGoesBy varchar,
 inDeath date
) RETURNS integer AS $$
DECLARE
 name_id integer;
 goesBy_id integer;
 exists_id integer;
 return_id integer;
BEGIN
 -- Check for possible duplicate before inserting Name
 exists_id := (
   SELECT exists.id
   FROM DUAL -- If first, last and birthday match any existing, consider it a duplicate and refuse to insert new Individual with this function
   LEFT JOIN Given ON Given.value = inFirst
   LEFT JOIN Family ON Family.value = inLast
   LEFT JOIN Name ON ((Name.given = Given.id) OR (Name.given IS NULL AND Given.id IS NULL))
    AND ((Name.family = Family.id) OR (Name.family IS NULL AND Family.id IS NULL))
   LEFT JOIN Individual AS exists ON exists.name IN (name_id, Name.id)
    AND ((CAST(exists.birth AS DATE) = inBirth) OR (inBirth IS NULL))
   LIMIT 1
 );

 IF exists_id IS NULL THEN
  name_id := (SELECT GetName(inFirst,inMiddle,inLast));
  goesBy_id := (SELECT GetGiven(inGoesBy));

  IF name_id IS NOT NULL THEN
   INSERT INTO Individual(name, goesBy, birth, death) VALUES (name_id, goesBy_id, inBirth, inDeath);
  END IF;

  return_id := (
   SELECT id
   FROM Individual
   WHERE Individual.name = name_id
   AND (CAST(Individual.birth AS DATE) = inBirth) -- Null birth inserts are not allowd in this function
   AND ((Individual.goesBy = goesBy_id) OR (goesBy_id IS NULL))
   AND ((CAST(Individual.death AS DATE) = inDeath) OR (Individual.death IS NULL AND inDeath IS NULL))
   LIMIT 1
  );
 ELSE
  return_id := exists_id;
 END IF;

 RETURN return_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetEntityName (
 inName varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF inName IS NOT NULL THEN
  INSERT INTO Entity (name)
  SELECT inName
  FROM DUAL
  LEFT JOIN Entity AS exists ON UPPER(exists.name) = UPPER(inName)
  WHERE exists.id IS NULL
  ;
 END IF;
 RETURN (
  SELECT id
  FROM Entity
  WHERE UPPER(Entity.name) = UPPER(inName)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar,
 inFormed date,
 inGoesBy varchar,
 inDissolved date
) RETURNS integer AS $$
DECLARE
 entity_name_id integer;
 goesBy_id integer;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  goesBy_id := (SELECT GetGiven(inGoesBy));

  INSERT INTO Individual (entity, goesBy, birth, death)
  SELECT entity_name_id, goesBy_id, inFormed, inDissolved
  FROM DUAL
  LEFT JOIN Individual AS exists ON exists.entity = entity_name_id
  WHERE exists.id IS NULL
  ; 
 END IF;
 RETURN (
  SELECT id FROM Individual
  WHERE Individual.entity = entity_name_id
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualListName (
 inListName varchar,
 inSetName varchar
) RETURNS integer AS $$
DECLARE
 listName_id integer;
 setName_id integer;
 individualList_id integer;
BEGIN
 IF inListName IS NOT NULL THEN
  -- Get names
  listName_id := (SELECT GetWord(inListName));
  setName_id := (SELECT GetWord(inSetName));
 
    -- Insert list name if it does not exist
  INSERT INTO IndividualListName (name, set, optinStyle)
  SELECT listName_id, setName_id, 1
  FROM DUAL
  LEFT JOIN IndividualListName AS exists ON exists.name = listName_id
   AND ((exists.set = setName_id) OR (exists.set IS NULL AND setName_id IS NULL))
   AND optinStyle = 1
  WHERE exists.individualList IS NULL
  ;
 END IF;

  -- Get individual list
 RETURN (
  SELECT individualList
  FROM IndividualListName
  WHERE name = listName_id
   AND ((set = setName_id) OR (set IS NULL AND setName_id IS NULL))
   AND optinStyle = 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inIndividual integer,
 inListName varchar,
 inSetName varchar
) RETURNS integer AS $$
DECLARE
 individualList_id integer;
BEGIN
 IF inIndividual IS NOT NULL THEN
  individualList_id := (SELECT GetIndividualListName(inListName, inSetName));

  -- Insert individual into list
  INSERT INTO IndividualList (id, individual)
  SELECT individualList_id AS id, inIndividual AS individual
  FROM DUAL
  LEFT JOIN IndividualList AS exists ON exists.id = individualList_id
   AND exists.individual = inIndividual
   AND exists.unlist IS NULL
  WHERE exists.id IS NULL;
 END IF;

 RETURN individualList_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inIndividual integer,
 inListName varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListSubscribe(inIndividual, inListName, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inIndividual integer,
 inListName varchar,
 inSetName varchar
) RETURNS integer AS $$
DECLARE
 individualList_id integer;
BEGIN
 IF inIndividual IS NOT NULL THEN
  individualList_id := (SELECT GetIndividualListName(inListName, inSetName));

  IF individualList_id IS NOT NULL THEN
   UPDATE IndividualList SET unlist = NOW()
   WHERE IndividualList.id = individualList_id
    AND IndividualList.individual = inIndividual
    AND IndividualList.unlist IS NULL
   ;
  END IF;

 END IF;

 RETURN individualList_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inIndividual integer,
 inListName varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListUnSubscribe(inIndividual, inListName, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetEmail (
 inUserName varchar,
 inPlus varchar,
 inHost varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF inUserName IS NOT NULL AND inHost IS NOT NULL THEN
  INSERT INTO Email (username, plus, host) (
   SELECT inUserName, inPlus, inHost
   FROM DUAL
   LEFT JOIN Email AS exists ON UPPER(exists.username) = UPPER(inUserName)
    AND UPPER(exists.host) = UPPER(inHost)
    AND ((UPPER(exists.plus) = UPPER(inPlus)) OR (exists.plus IS NULL AND inPlus IS NULL))
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Email
  WHERE UPPER(username) = UPPER(inUserName)
   AND UPPER(host) = UPPER(inHost)
   AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
 );
END;
$$ LANGUAGE plpgsql;
