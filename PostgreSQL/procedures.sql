-- The MIT License (MIT) Copyright (c) 2014-2018 Stephen A Jazdzewski
-- Officially, PostgreSQL only has "functions"
-- These links may help
-- http://www.sqlines.com/postgresql/stored_procedures_functions
-- http://www.sqlines.com/postgresql/how-to/return_result_set_from_stored_procedure
SET search_path TO Business,"$user",public;

-- Return the Id of a culture based word
-- It is inserted if it does not already exist
CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF word_value IS NOT NULL THEN
  -- Be sure to process any single value one at a time without the need of a transaction or locking Word table
  PERFORM pg_advisory_lock(hashtext(word_value));
  INSERT INTO Word (value, culture) (
   SELECT word_value, Culture.code
   FROM Culture
   LEFT JOIN Word AS exists ON UPPER(exists.value) = UPPER(word_value)
    AND exists.culture = Culture.code
   WHERE UPPER(Culture.name) = UPPER(culture_name)
    AND exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(word_value));
 END IF;
 RETURN (
  SELECT id
  FROM Word
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Word.value) = UPPER(word_value)
   AND Word.culture = Culture.code
  LIMIT 1
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

-- Identifiers are normally by convention en-US based names used in programming and protocols
-- Return the Id of an identifier
-- It is inserted if it does not already exist
CREATE OR REPLACE FUNCTION GetIdentifier (
 ident_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF ident_value IS NOT NULL THEN
  -- Be sure to process any single value one at a time without the need of a transaction or locking Word table
  PERFORM pg_advisory_lock(hashtext(ident_value));
  INSERT INTO Word (value, culture) (
   SELECT ident_value, NULL
   FROM Dual
   LEFT JOIN Word AS exists ON UPPER(exists.value) = UPPER(ident_value)
    AND exists.culture IS NULL
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(ident_value));
 END IF;
 RETURN (
  SELECT id
  FROM Word
  WHERE UPPER(Word.value) = UPPER(ident_value)
   AND Word.culture IS NULL
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF sentence_value IS NOT NULL THEN
  -- Be sure to process any single value one at a time without the need of a transaction or locking Sentence table
  PERFORM pg_advisory_lock(hashtext(sentence_value));
  INSERT INTO Sentence (value, culture, length) (
   SELECT sentence_value, Culture.code, LENGTH(sentence_value)
   FROM Culture
   LEFT JOIN Sentence AS exists ON UPPER(exists.value) = UPPER(sentence_value)
    AND exists.culture = Culture.code
   WHERE UPPER(Culture.name) = UPPER(culture_name)
    AND exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(sentence_value));
 END IF;
 RETURN (
  SELECT id
  FROM Sentence
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Sentence.value) = UPPER(sentence_value)
   AND Sentence.culture = Culture.code
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- Default to en-US
CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT GetSentence(sentence_value, 'en-US') AS id
 );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetIdentityPhrase (
 phrase_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF phrase_value IS NOT NULL THEN
  -- Be sure to process any single value one at a time without the need of a transaction or locking Sentence table
  PERFORM pg_advisory_lock(hashtext(phrase_value));
  INSERT INTO Sentence (value, culture) (
   SELECT phrase_value, NULL
   FROM Dual
   LEFT JOIN Sentence AS exists ON UPPER(exists.value) = UPPER(phrase_value)
    AND exists.culture IS NULL
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(phrase_value));
 END IF;
 RETURN (
  SELECT id
  FROM Sentence
  WHERE UPPER(Sentence.value) = UPPER(phrase_value)
   AND Sentence.culture IS NULL
  LIMIT 1
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
 lockID bigint;
BEGIN
 inLatitude := lat;
 inLongitude := long;

 IF lat IS NOT NULL AND long IS NOT NULL THEN
  -- Convert latitude numeric(10,7) to a 64 bit integer for lock
  lockID := (inLatitude * 10000000)::bigint;
  -- Be sure to process any single latitude one at a time without the need of a transaction or locking the Location table
  PERFORM pg_advisory_lock(lockID);
  INSERT INTO Location (latitude, longitude, accuracy) (
   SELECT inLatitude, inLongitude, accuracy_code
   FROM Dual
   LEFT JOIN Location AS exists ON exists.latitude = inLatitude
    AND exists.longitude = inLongitude
    AND ((exists.accuracy = accuracy_code) OR (exists.accuracy IS NULL AND accuracy_code IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
   PERFORM pg_advisory_unlock(lockID);
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
  LIMIT 1
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
 -- Be sure to process any single zipcode one at a time without the need of a transaction or locking the Postal table
 PERFORM pg_advisory_lock(hashtext(UPPER(zipcode)));
 INSERT INTO Postal (country, code, state, stateabbreviation, county, city, location) (
  SELECT countrycode_id, zipcode, state_id, statecode_id, county_id, city_id, location_id
  FROM Dual
  LEFT JOIN Postal AS exists ON exists.country = countrycode_id
   AND UPPER(exists.code) = UPPER(zipcode)
  WHERE exists.id IS NULL
  LIMIT 1
 );
 PERFORM pg_advisory_unlock(hashtext(UPPER(zipcode)));
 RETURN (
  SELECT id
  FROM Postal
  -- Unique on country and code
  WHERE country = countrycode_id
   AND UPPER(Postal.code) = UPPER(zipcode)
  LIMIT 1
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
  ORDER BY id DESC
  LIMIT 1
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
  ORDER BY id DESC
  LIMIT 1
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
   -- Be sure to process any single zipcode id one at a time without the need of a transaction or locking the Address table
   PERFORM pg_advisory_lock(zipcode_id);
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
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(zipcode_id);
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
   LIMIT 1
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
  -- Do not call GetPostal with nulls so that this will return addresses with location information
  zipcode_id := (SELECT GetPostal(zipcode));

  IF zipcode_id IS NOT NULL THEN
   -- Be sure to process any single zipcode id one at a time without the need of a transaction or locking the Address table
   PERFORM pg_advisory_lock(zipcode_id);
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
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(zipcode_id);
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
  -- Be sure to process any single given one at a time without the need of a transaction or locking Given table
  PERFORM pg_advisory_lock(hashtext(inGiven));
  INSERT INTO Given (value) (
   SELECT inGiven
   FROM DUAL
   LEFT JOIN Given AS exists ON exists.value = inGiven
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(inGiven));
 END IF;

 RETURN (
  SELECT id
  FROM Given
  WHERE Given.value = inGiven
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFamily (
 inFamily varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF inFamily IS NOT NULL THEN
  -- Be sure to process any single family one at a time without the need of a transaction or locking Family table
  PERFORM pg_advisory_lock(hashtext(inFamily));
  INSERT INTO Family (value) (
   SELECT inFamily
   FROM DUAL
   LEFT JOIN Family AS exists ON exists.value = inFamily
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(inFamily));
 END IF;
 RETURN (
  SELECT id
  FROM Family
  WHERE Family.value = inFamily
  LIMIT 1
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

  -- Be sure to process any single first one at a time without the need of a transaction or locking Name table
  PERFORM pg_advisory_lock(first_id);
  INSERT INTO Name (given, middle, family) (
   SELECT first_id, middle_id, last_id
   FROM DUAL
   LEFT JOIN Name AS exists ON
        ((exists.given = first_id) OR (exists.given IS NULL AND first_id IS NULL))
    AND ((exists.middle = middle_id) OR (exists.middle IS NULL AND middle_id IS NULL))
    AND ((exists.family = last_id) OR (exists.family IS NULL AND last_id IS NULL))
  WHERE exists.id IS NULL
  LIMIT 1
  );
  PERFORM pg_advisory_unlock(first_id);
 END IF;

 RETURN (
  SELECT id
  FROM Name
  WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
    AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
    AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualPerson (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar,
 inBirth date, -- Can't be null
 inGoesBy varchar,
 inDeath date
) RETURNS bigint AS $$
DECLARE
 name_id integer;
 goesBy_id integer;
 exists_id bigint;
 return_id bigint;
 lockID bigint;
BEGIN
 -- Check for possible duplicate before inserting Name
 -- Be sure to process any single birthdate one at a time without the need of a transaction or locking the Individual table
 lockID := extract(epoch FROM inBirth)::bigint;
 PERFORM pg_advisory_lock(lockID);

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
 PERFORM pg_advisory_unlock(lockID);

 RETURN return_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetEntityName (
 inName varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF inName IS NOT NULL THEN
  -- Be sure to process any single name one at a time without the need of a transaction or locking the Entity table
  PERFORM pg_advisory_lock(hashtext(inName));
  INSERT INTO Entity (name)
  SELECT inName
  FROM DUAL
  LEFT JOIN Entity AS exists ON UPPER(exists.name) = UPPER(inName)
  WHERE exists.id IS NULL
  LIMIT 1
  ;
  PERFORM pg_advisory_unlock(hashtext(inName));
 END IF;
 RETURN (
  SELECT id
  FROM Entity
  WHERE UPPER(Entity.name) = UPPER(inName)
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar,
 inFormed date,
 inGoesBy varchar,
 inDissolved date
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 goesBy_id integer;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  goesBy_id := (SELECT GetGiven(inGoesBy));

  -- Be sure to process any single entity name id one at a time without the need of a transaction or locking Individual table
  PERFORM pg_advisory_lock(entity_name_id);
  INSERT INTO Individual (entity, goesBy, birth, death)
  SELECT entity_name_id, goesBy_id, inFormed, inDissolved
  FROM DUAL
  LEFT JOIN Individual AS exists ON exists.entity = entity_name_id
  WHERE exists.id IS NULL
  LIMIT 1
  ;
  PERFORM pg_advisory_unlock(entity_name_id);
 END IF;
 RETURN (
  SELECT id FROM Individual
  WHERE Individual.entity = entity_name_id
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 individual_id bigint;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  -- Be sure to process any single entity name id one at a time without the need of a transaction or locking Individual table
  PERFORM pg_advisory_lock(entity_name_id);
  individual_id := (
   SELECT id
   FROM Individual
   WHERE entity = entity_name_id
   LIMIT 1
  );
  IF individual_id IS NULL THEN
   INSERT INTO Individual (entity) VALUES (entity_name_id) RETURNING id INTO individual_id;
  END IF;
  PERFORM pg_advisory_unlock(entity_name_id);
 END IF;
 RETURN individual_id;
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
  -- Be sure to process any single username one at a time without the need of a transaction or locking Email table
  PERFORM pg_advisory_lock(hashtext(inUserName));
  INSERT INTO Email (username, plus, host) (
   SELECT inUserName, inPlus, inHost
   FROM DUAL
   LEFT JOIN Email AS exists ON UPPER(exists.username) = UPPER(inUserName)
    AND UPPER(exists.host) = UPPER(inHost)
    AND ((UPPER(exists.plus) = UPPER(inPlus)) OR (exists.plus IS NULL AND inPlus IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(inUserName));
 END IF;
 RETURN (
  SELECT id
  FROM Email
  WHERE UPPER(username) = UPPER(inUserName)
   AND UPPER(host) = UPPER(inHost)
   AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetEmail (
 inEmail varchar
) RETURNS integer AS $$
DECLARE
 userHostSplit varchar[];  -- Remember these start at 1 not 0
 userPlusSplit varchar[];
BEGIN
 IF inEmail IS NOT NULL THEN
  userHostSplit := (SELECT (regexp_split_to_array(inEmail,'@'))[1:2]);
  userPlusSplit := (SELECT (regexp_split_to_array(userHostSplit[1],'\+'))[1:2]);
 END IF;
 RETURN (
  SELECT GetEmail(userPlusSplit[1], userPlusSplit[2], userHostSplit[2]) AS id
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetListIndividualName (
 inListName varchar,
 inSetName varchar
) RETURNS integer AS $$
DECLARE
 listName_id integer;
 setName_id integer;
 listIndividual_id integer;
BEGIN
 IF inListName IS NOT NULL THEN
  -- Get names
  listName_id := (SELECT GetWord(inListName));
  setName_id := (SELECT GetWord(inSetName));
 
  -- Insert list name if it does not exist
  -- Be sure to process any single list name id one at a time without the need of a transaction or locking ListIndividualName table
  PERFORM pg_advisory_lock(listName_id);
  INSERT INTO ListIndividualName (name, listSet, optinStyle)
  SELECT listName_id, setName_id, 1
  FROM DUAL
  LEFT JOIN ListIndividualName AS exists ON exists.name = listName_id
   AND ((exists.listSet = setName_id) OR (exists.listSet IS NULL AND setName_id IS NULL))
   AND exists.optinStyle = 1
  WHERE exists.listIndividual IS NULL
  LIMIT 1
  ;
  PERFORM pg_advisory_unlock(listName_id);
 END IF;

 -- Get individual list
 RETURN (
  SELECT listIndividual
  FROM ListIndividualName
  WHERE name = listName_id
   AND ((listSet = setName_id) OR (listSet IS NULL AND setName_id IS NULL))
   AND optinStyle = 1
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual bigint,
 inSend varchar
) RETURNS integer AS $$
DECLARE
 listIndividual_id integer;
 sendField_id integer;
BEGIN
 IF inIndividual IS NOT NULL AND inListName IS NOT NULL THEN
  sendField_id := (SELECT GetIdentifier(LOWER(inSend)));
  listIndividual_id := (SELECT GetListIndividualName(inListName, inSetName));

  -- Insert individual into list
  -- Be sure to process any single list individual id one at a time without the need of a transaction or locking ListIndividual table
  PERFORM pg_advisory_lock(listIndividual_id);
  INSERT INTO ListIndividual (id, individual, type)
  SELECT listIndividual_id AS id, inIndividual AS individual, sendField_id AS type
  FROM DUAL
  LEFT JOIN ListIndividual AS exists ON exists.id = listIndividual_id
   AND exists.individual = inIndividual
   AND exists.unlist IS NULL
  WHERE exists.id IS NULL
  LIMIT 1
  ;
  PERFORM pg_advisory_unlock(listIndividual_id);
 END IF;

 RETURN listIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual bigint
) RETURNS integer AS $$
BEGIN
 -- Use default send to
 RETURN (SELECT ListSubscribe(inListName, inSetName, inIndividual, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName varchar,
 inIndividual bigint
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListSubscribe(inListName, NULL, inIndividual));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual bigint
) RETURNS integer AS $$
DECLARE
 listIndividual_id integer;
BEGIN
 IF inIndividual IS NOT NULL AND inListName IS NOT NULL THEN
  listIndividual_id := (SELECT GetListIndividualName(inListName, inSetName));

  IF listIndividual_id IS NOT NULL THEN
   UPDATE ListIndividual SET unlist = NOW()
   WHERE ListIndividual.id = listIndividual_id
    AND ListIndividual.individual = inIndividual
    AND ListIndividual.unlist IS NULL
   ;
  END IF;

 END IF;

 RETURN listIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName varchar,
 inIndividual bigint
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListUnSubscribe(inListName, NULL, inIndividual));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CreateIndividual (
) RETURNS bigint AS $$
DECLARE
BEGIN
 INSERT INTO Individual (birth) VALUES(NULL);
 RETURN (SELECT currval(pg_get_serial_sequence('individual','id')));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id bigint,
 inEmail_id integer,
 inType varchar
) RETURNS bigint AS $$
DECLARE
 type_id integer;
BEGIN
 IF inIndividual_id IS NOT NULL
  AND inEmail_id IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  -- Be sure to process any single individual email one at a time without the need of a transaction or locking IndividualEmail table
  PERFORM pg_advisory_lock(inIndividual_id);
  INSERT INTO IndividualEmail (individual, email, type) (
   SELECT inIndividual_id, inEmail_id, type_id
   FROM DUAL
   LEFT JOIN IndividualEmail AS exists ON exists.individual = inIndividual_id
    AND exists.email = inEmail_id
    AND ((exists.type = type_id) OR (exists.type IS NULL AND type_id IS NULL))
    AND exists.stop IS NULL
   WHERE exists.individual IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inIndividual_id);
  -- Be sure to stop any previous emails of this type associated with this individual
  UPDATE IndividualEmail
  SET stop = NOW()
  WHERE individual = inIndividual_id
   AND email != inEmail_id
   AND Stop IS NULL
   AND ((type = type_id) OR (type IS NULL AND type_id IS NULL))
  ;
 END IF;
 RETURN inIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id bigint,
 inEmail_id integer
) RETURNS bigint AS $$
DECLARE
BEGIN
 RETURN SetIndividualEmail(inIndividual_id, inEmail_id, NULL);
END;
$$ LANGUAGE plpgsql;

-- Get Individual associated with an email
CREATE OR REPLACE FUNCTION GetIndividualEmail (
  inEmail varchar
) RETURNS bigint AS $$
DECLARE
 email_id integer;
 individual_id bigint;
BEGIN
 -- Get email id
 email_id := (SELECT GetEmail(inEmail));

 IF email_id IS NOT NULL THEN
  -- Is email already associated with an individual?
  individual_id := (
   SELECT individual
   FROM IndividualEmail
   WHERE email = email_id
    AND stop IS NULL
   LIMIT 1
  );

  IF individual_id IS NULL THEN
   -- Email not associated with any individual, so create new individual
   individual_id = (SELECT CreateIndividual());
  END IF;

  -- Associate email with individual
  PERFORM SetIndividualEmail(individual_id, email_id);

 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribeEmail (
 inListName varchar,
 inSetName varchar,
 inEmail varchar
) RETURNS integer AS $$
DECLARE
 individual_id bigint;
BEGIN
 individual_id := (GetIndividualEmail(inEmail));

 -- Subscribe individual to the list
 RETURN (SELECT ListSubscribe(inListName, inSetName, individual_id));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribeEmail (
 inListName varchar,
 inEmail varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (SELECT ListSubscribeEmail(inListName, NULL, inEmail));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetVersion (
 inMajor varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE
 major_id integer;
 minor_id integer;
 patch_id integer;
BEGIN
 major_id := (SELECT GetWord(inMajor));
 IF major_id IS NOT NULL THEN
  minor_id := (SELECT GetWord(inMinor));
  patch_id := (SELECT GetWord(inPatch));
  -- Be sure to process any single version one at a time without the need of a transaction or locking Version table
  PERFORM pg_advisory_lock(major_id);
  INSERT INTO Version (major, minor, patch) (
   SELECT major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS exists ON exists.major = major_id
    AND ((exists.minor = minor_id) OR (exists.minor IS NULL AND minor_id IS NULL))
    AND ((exists.patch = patch_id) OR (exists.patch IS NULL AND patch_id IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(major_id);
 END IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE major = major_id
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
   AND name IS NULL
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetVersionName (
 inName varchar,
 inMajor varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 major_id integer;
 minor_id integer;
 patch_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetWord(inName));
  major_id := (SELECT GetWord(inMajor));
  minor_id := (SELECT GetWord(inMinor));
  patch_id := (SELECT GetWord(inPatch));
  -- Be sure to process any single version name one at a time without the need of a transaction or locking Version table
  PERFORM pg_advisory_lock(name_id);
  INSERT INTO Version (name, major, minor, patch) (
   SELECT name_id, major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS exists ON exists.name = name_id
    AND ((exists.major = major_id) OR (exists.major IS NULL AND major_id IS NULL))
    AND ((exists.minor = minor_id) OR (exists.minor IS NULL AND minor_id IS NULL))
    AND ((exists.patch = patch_id) OR (exists.patch IS NULL AND patch_id IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(name_id);
 END IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE name = name_id
   AND ((major = major_id) OR (major IS NULL AND major_id IS NULL))
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetVersionName (
 inName varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (SELECT GetVersionName(inName, NULL, NULL, NULL));
END;
$$ LANGUAGE plpgsql;


-- GetRelease(version integer, build char)
CREATE OR REPLACE FUNCTION GetRelease (
 inVersion integer,
 inBuild varchar
) RETURNS integer AS $$
DECLARE build_id integer;
BEGIN
 IF inVersion IS NOT NULL THEN
  build_id := (SELECT GetWord(inBuild));
  -- Be sure to process any single version build one at a time without the need of a transaction or locking Release table
  PERFORM pg_advisory_lock(inVersion);
  INSERT INTO Release (build, version) (
   SELECT build_id AS build, inVersion AS version
   FROM Dual
   LEFT JOIN Release AS exists ON exists.version = inVersion
    AND ((exists.build = build_id) OR (exists.build IS NULL AND build_id IS NULL)) 
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inVersion);
 END IF;
 RETURN (
  SELECT id
  FROM Release
  WHERE version = inVersion
   AND ((build = build_id) OR (build IS NULL AND build_id IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- GetRelease(version integer)
CREATE OR REPLACE FUNCTION GetRelease (
 inVersion integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetRelease(inVersion, NULL));
END;
$$ LANGUAGE plpgsql;

-- GetApplication(name char)
CREATE OR REPLACE FUNCTION GetApplication(
 inName varchar
) RETURNS integer AS $$
DECLARE name_ident integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_ident := (SELECT GetWord(inName));
  -- Be sure to process any single application one at a time without the need of a transaction or locking Application table
  PERFORM pg_advisory_lock(name_ident);
  INSERT INTO Application (name) (
   SELECT name_ident AS name
   FROM Dual
   LEFT JOIN Application AS exists ON exists.name = name_ident
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(name_ident);
 END IF;
 RETURN (
  SELECT id
  FROM Application
  WHERE name = name_ident
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- GetApplicationRelease(application integer, release integer)
CREATE OR REPLACE FUNCTION GetApplicationRelease (
 inApplication integer,
 inRelease integer
) RETURNS integer AS $$
BEGIN
 IF inApplication IS NOT NULL THEN
  -- Be sure to process any single application release one at a time without the need of a transaction or locking ApplicationRelease table
  PERFORM pg_advisory_lock(inApplication);
  INSERT INTO ApplicationRelease (application, release) (
   SELECT inApplication AS application, inRelease AS release
   FROM Dual
   LEFT JOIN ApplicationRelease AS exists ON exists.application = inApplication
    AND ((exists.release = inRelease) OR (exists.release IS NULL AND inRelease IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inApplication);
 END IF;
 RETURN (
  SELECT id
  FROM ApplicationRelease
  WHERE application = inApplication
   AND ((release = inRelease) OR (release IS NULL AND inRelease IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- GetPart(name varchar)
-- Getting a Part without a version returns a root part with a null parent, version and serial
CREATE OR REPLACE FUNCTION GetPart (
 inName varchar
) RETURNS integer AS $$
DECLARE name_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
  PERFORM pg_advisory_lock(name_id);
  INSERT INTO Part (name) (
   SELECT name_id
   FROM Dual
   LEFT JOIN Part AS exists ON exists.name = name_id
    AND exists.parent IS NULL
    AND exists.version IS NULL
    AND exists.serial IS NULL
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(name_id);
 END IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent IS NULL
   AND version IS NULL
   AND serial IS NULL
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- GetPartWithParent(name varchar, parentId integer) Specify an exact parent for Part without version
CREATE OR REPLACE FUNCTION GetPartWithParent (
 inNameId integer,
 inParentId integer
) RETURNS integer AS $$
BEGIN
 IF inNameId IS NOT NULL AND inParentId IS NOT NULL THEN
  -- Insert if it does not alread exists
  -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
  PERFORM pg_advisory_lock(inNameId);
  INSERT INTO Part (name, parent) (
   SELECT inNameId, inParentId
   FROM Dual
   LEFT JOIN Part AS exists ON exists.name = inNameId
    AND exists.parent = inParentId
    AND exists.version IS NULL
    AND exists.serial IS NULL
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inNameId);
 END IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = inNameId
   AND parent = inParentId
   AND version IS NULL
   AND serial IS NULL
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPartWithParent (
 inName varchar,
 inParentId integer
) RETURNS integer AS $$
DECLARE name_id integer;
BEGIN
 name_id := (SELECT GetSentence(inName));
 RETURN (
  SELECT GetPartWithParent(name_id, inParentId)
 );
END;
$$ LANGUAGE plpgsql;

-- Child and Parent by name when building a non-versioned part hierarchy
CREATE OR REPLACE FUNCTION GetPartWithParent (
 inPartName varchar,
 inParentName varchar
) RETURNS integer AS $$
DECLARE part_name_id integer;
DECLARE parent_name_id integer;
DECLARE parent_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inParentName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  parent_name_id := (SELECT GetSentence(inParentName));

  -- Find the lowest non-versioned part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND version IS NULL
    AND serial IS NULL
   ORDER BY parent ASC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create a root part
   parent_id := (SELECT GetPart(inParentName));
  END IF;
  RETURN (
   SELECT GetPartWithParent(part_name_id, parent_id)
  );
 END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPartWithParent (
 inPartName varchar,
 inParentName varchar,
 inParentVersionName varchar
) RETURNS integer AS $$
DECLARE part_name_id integer;
DECLARE parent_name_id integer;
DECLARE parent_version_name_id integer;
DECLARE parent_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inParentName IS NOT NULL AND inParentVersionName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  parent_name_id := (SELECT GetSentence(inParentName));
  parent_version_name_id := GetVersionName(inParentVersionName);
  -- Find the lowest version name part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND version = parent_version_name_id
    AND serial IS NULL
   ORDER BY parent ASC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create parent
   parent_id := (SELECT GetPart(inParentName,inParentVersionName));
  END IF;
  RETURN (
   SELECT GetPartWithParent(part_name_id, parent_id)
  );
 END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersion integer
) RETURNS integer AS $$
DECLARE name_id integer;
DECLARE sibling_id integer;
DECLARE parent_id integer;
BEGIN
 IF inName IS NOT NULL AND inVersion IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  -- Every non-root part must have a parent
  -- Does it have a direct sibling with a parent?
  sibling_id := (SELECT Part.parent
   FROM Part
   WHERE Part.name = name_id
    AND Part.version IS NOT NULL
    AND Part.serial IS NULL
   LIMIT 1
  );
  IF sibling_id IS NULL THEN
   -- No siblings, try same part without a version but has a parent
   parent_id := (SELECT Part.id
    FROM Part
    WHERE Part.name = name_id
     AND Part.parent IS NOT NULL
     AND Part.version IS NULL
     AND Part.serial IS NULL
     LIMIT 1
   );
   IF parent_id IS NULL THEN
    -- Try same part without version or parent (root part)
    -- If not found it will create it
    parent_id := (SELECT GetPart(inName));
   END IF;
  ELSE
   -- Use sibling parent
   parent_id := sibling_id;
  END IF;
  -- Insert this part if it is not a duplicate
  -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
  PERFORM pg_advisory_lock(parent_id);
  INSERT INTO Part (parent, name, version) (
   SELECT parent_id, name_id, inVersion
   FROM Dual
   LEFT JOIN Part AS exists ON exists.parent = parent_id
    AND exists.name = name_id
    AND exists.version = inVersion
    AND exists.serial IS NULL
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(parent_id);
 END IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent = parent_id
   AND version = inVersion
   AND serial IS NULL
  LIMIT 1
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 version_id := (SELECT GetVersionName(inVersionName));
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar,
 inMajor  varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 IF inVersionName IS NOT NULL THEN
  version_id := (SELECT GetVersionName(inVersionName, inMajor, NULL, NULL));
 ELSE
  version_id := (SELECT GetVersion(inMajor, NULL, NULL));
 END IF;
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar,
 inMajor  varchar,
 inMinor varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 IF inVersionName IS NOT NULL THEN
  version_id := (SELECT GetVersionName(inVersionName, inMajor, inMinor, NULL));
 ELSE
  version_id := (SELECT GetVersion(inMajor, inMinor, NULL));
 END IF;
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar,
 inMajor  varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 IF inVersionName IS NOT NULL THEN
  version_id := (SELECT GetVersionName(inVersionName, inMajor, inMinor, inPatch));
 ELSE
  version_id := (SELECT GetVersion(inMajor, inMinor, inPatch));
 END IF;
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

-- Pass in the parent part that will be copied to new part with serial number
CREATE OR REPLACE FUNCTION GetPartbySerial (
 inParent integer,
 inSerial varchar
) RETURNS integer AS $$
BEGIN
 IF inParent IS NOT NULL THEN
  -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
  PERFORM pg_advisory_lock(inParent);
  INSERT INTO Part (parent, name, version, serial) (
   SELECT inParent, parent.name, parent.version, inSerial
   FROM Part AS parent
   LEFT JOIN Part AS exists ON exists.parent = inParent
    AND exists.serial = inSerial
   WHERE parent.id = inParent
    AND exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inParent);
 END IF;
 RETURN (
  SELECT part.id
  FROM Part
  WHERE Part.parent = inParent
   AND Part.serial = inSerial
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- Used in other GetAssembly functions
CREATE OR REPLACE FUNCTION PutAssemblyPart (
 inAssembly integer,
 inPart integer,
 inDesignator varchar,
 inQuantity integer
) RETURNS void AS $$
DECLARE designator_id integer;
BEGIN
 IF inAssembly IS NOT NULL THEN
  designator_id := GetWord(inDesignator);
  -- Be sure to process any single assembly one at a time without the need of a transaction or locking AssemblyPart table
  PERFORM pg_advisory_lock(inAssembly);
  INSERT INTO AssemblyPart (assembly, part, designator, quantity) (
   SELECT inAssembly, inPart, designator_id, inQuantity
   FROM Dual
   LEFT JOIN AssemblyPart AS exists ON exists.assembly = inAssembly
    AND exists.part = inPart
    AND ((exists.designator = designator_id) OR (exists.designator IS NULL AND designator_id IS NULL))
    AND ((exists.quantity = inQuantity) OR (exists.quantity IS NULL AND inQuantity IS NULL))
   WHERE exists.assembly IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inAssembly);
 END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION PutAssemblyPart (
 inAssemblyName varchar,
 inAssemblyVersion varchar,
 inAssemblyMajor  varchar,
 inAssemblyMinor varchar,
 inAssemblyPatch varchar,
 inPartName varchar,
 inPartVersion varchar,
 inPartMajor  varchar,
 inPartMinor varchar,
 inPartPatch varchar,
 inDesignator varchar,
 inQuantity integer
) RETURNS void AS $$
DECLARE assembly_id integer;
DECLARE part_id integer;
BEGIN
 assembly_id := GetPart(inAssemblyName, inAssemblyVersion, inAssemblyMajor, inAssemblyMinor, inAssemblyPatch);
 part_id := GetPart(inPartName, inPartVersion, inPartMajor, inPartMinor, inPartPatch);
 PERFORM PutAssemblyPart(assembly_id, part_id, inDesignator, inQuantity);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAssemblyApplicationRelease (
 inAssembly integer,
 inApplicationRelease integer,
 inParent integer
) RETURNS integer AS $$
BEGIN
 IF inAssembly IS NOT NULL AND inApplicationRelease IS NOT NULL THEN
  -- Be sure to process any single assmbly application release one at a time without the need of a transaction or locking AssemblyApplicationRelease table
  PERFORM pg_advisory_lock(inAssembly);
  INSERT INTO AssemblyApplicationRelease (parent, assembly, applicationRelease) (
   SELECT inParent AS parent, inAssembly AS assembly, inApplicationRelease AS applicationRelease
   FROM Dual
   LEFT JOIN AssemblyApplicationRelease AS exists ON exists.assembly = inAssembly
    AND exists.applicationRelease = inApplicationRelease
    AND ((exists.parent = inParent) OR (exists.parent IS NULL AND inParent IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inAssembly);
 END IF;
 RETURN (
  SELECT id
  FROM AssemblyApplicationRelease
  WHERE assembly = inAssembly
   AND applicationRelease = inApplicationRelease
   AND ((parent = inParent) OR (parent IS NULL AND inParent IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAssemblyApplicationRelease (
 inAssembly integer,
 inApplicationRelease integer
) RETURNS integer AS $$
BEGIN
RETURN (SELECT GetAssemblyApplicationRelease(inAssembly, inApplicationRelease, NULL));
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetPath (
 inProtocol varchar,
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar
) RETURNS integer AS $$
DECLARE is_secure integer := 0;
 lockText varchar;
 lockID bigint;
BEGIN
 -- host and path can not both be null
 IF inValue IS NOT NULL OR inHost IS NOT NULL THEN
  -- Default to false or 0
  IF inSecure IS NOT NULL AND inSecure != 0 THEN
    is_secure :=1;
  END IF;
  lockText := COALESCE(inHost, '') || COALESCE(inValue, '');
  lockID := hashtext(lockText);
  -- Be sure to process any single path one at a time without the need of a transaction or locking Path table
  PERFORM pg_advisory_lock(lockID);
  INSERT INTO Path (protocol, secure, host, value, get) (
   SELECT inProtocol, is_secure, inHost, inValue, inGet
   FROM Dual
   LEFT JOIN Path AS exists ON exists.protocol = inProtocol
    AND exists.secure = is_secure
    AND ((UPPER(exists.host) = UPPER(inHost)) OR (exists.host IS NULL AND inHost IS NULL))
    AND ((exists.value = inValue) OR (exists.value IS NULL OR inValue IS NULL))
    AND ((exists.get = inGet) OR (exists.get IS NULL AND inGet IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(lockID);
 END IF;
 RETURN (
  SELECT id
  FROM Path
  WHERE protocol = inProtocol
   AND secure = is_secure
   AND ((UPPER(host) = UPPER(inHost)) OR (host IS NULL and inHost IS NULL))
   AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
   AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetURL (
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetPath('http', inSecure, inHost, inValue, inGet));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFile (
 inHost varchar,
 inPathValue varchar,
 inFileGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetPath('file', 0, inHost, inPathValue, inFileGet));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPhone (
 inCountryCode varchar,
 inAreaCode varchar,
 inNumber varchar
) RETURNS integer AS $$
DECLARE
 countrycode_id integer;
BEGIN
 IF inNumber IS NOT NULL THEN
  countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(inCountryCode));
  -- Be sure to process any single phone number one at a time without the need of a transaction or locking Phone table
  IF countrycode_id IS NOT NULL THEN
   PERFORM pg_advisory_lock(hashtext(inNumber));
   INSERT INTO Phone (country, area, number) (
    SELECT countrycode_id, inAreaCode, inNumber
    FROM Dual
    LEFT JOIN Phone AS exists ON exists.country = countrycode_id
     AND exists.area = inAreaCode
     AND exists.number = inNumber
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(hashtext(inNumber));
  END IF;
 END IF;
 RETURN (
  SELECT id
  FROM Phone
  WHERE country = countrycode_id
   AND area = inAreaCode
   AND number = inNumber
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;


-- For examples only.  Don't use in a production environment
CREATE OR REPLACE FUNCTION RandomString (
 inLength integer
) RETURNS varchar AS $$
DECLARE base_chars varchar[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
DECLARE base integer := 62;
DECLARE x integer;
DECLARE result_string varchar;
BEGIN
 IF inLength > 0 THEN
  result_string := '';
  FOR x IN 1..inLength LOOP
   result_string := result_string || base_chars[ceiling(random()*base)];
  END LOOP;
 END IF;
 RETURN result_string;
END;
$$ LANGUAGE plpgsql;

-- Returns an AssemblyApplicationRelease id for device, os and application.  OS is the parent.
CREATE OR REPLACE FUNCTION GetDeviceOSApplicationRelease (
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar
) RETURNS integer AS $$
DECLARE deviceName VARCHAR;
DECLARE deviceId integer;
DECLARE deviceVersionId integer;
BEGIN
 deviceName := (SELECT COALESCE(inDeviceFamily, 'Unknown'));
 -- User Device Agent SessionCredential.agent field, references AssemblyApplicationRelease.id
 -- Detect device family version
 IF inDeviceFamilyVersion IS NOT NULL THEN
  deviceVersionId := (SELECT GetVersionName(inDeviceFamilyVersion, NULL, NULL, NULL));
  deviceId := (SELECT GetPart(deviceName, deviceVersionId));
 ELSE
  deviceId := (SELECT GetPart(deviceName));
 END IF;

 RETURN (SELECT GetAssemblyApplicationRelease(
   -- device
   deviceId,
   -- application release id
   GetApplicationRelease(
    -- application id
    GetApplication(inUAfamily),
    -- application release
    GetRelease(
     -- application version
     GetVersion(inUAmajor,inUAminor,inUApatch),
     inUAbuild)
   ),
   -- device os
   GetAssemblyApplicationRelease(
    --device
    deviceId,
    --os release id
    GetApplicationRelease(
     -- os id
     GetApplication(inOSfamily),
     -- os release
     GetRelease(
      -- os version
      GetVersionName(inOSfamily, inOSmajor, inOSminor, inOSpatch)
     )
    )
   )
  )
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetDeviceOSApplicationRelease (
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar
) RETURNS integer AS $$
BEGIN
RETURN (
 SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild, inOSfamily, inOSmajor, inOSminor, inOSpatch, inDeviceBrand, inDeviceModel, inDeviceFamily, NULL)
);
END;
$$ LANGUAGE plpgsql;

-- The function GetAgentString(inUAstring) can be used instead of a cache if the DB is fast enough
-- If all but sentence are null, then the parsed inUAstring needs to be inserted using GetDeviceOSApplicationRelease and GetAgentString(inAgent, inString)
-- agentstring can be used in SetSession calls
-- agentstring can be stored in a cache and looked up with inUAstring
CREATE OR REPLACE FUNCTION GetAgentString (
 inUAstring varchar
) RETURNS TABLE (agentstring integer,
 assemblyapplicationrelease integer, sentence integer,
 device varchar, os varchar, agent varchar) AS $$
DECLARE string_id integer;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));
 -- Does not actually insert an AgentString record.  Will return a NULL agentstring if a parsed agents string does not yet exist
 RETURN QUERY (
  SELECT AgentString.id AS agentstring,
   AgentString.agent, Sentence.id AS sentence,
   ParsedAgentStringShort.device,
   ParsedAgentStringShort.os,
   ParsedAgentStringShort.agent
  FROM Sentence
  LEFT JOIN AgentString ON AgentString.userAgentString = Sentence.id
  LEFT JOIN ParsedAgentStringShort ON ParsedAgentStringShort.agentstring = AgentString.id
  WHERE Sentence.culture IS NULL
   AND Sentence.id = string_id
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAgentString (
 inAgent integer,
 inString integer
) RETURNS integer AS $$
BEGIN
 IF inString IS NOT NULL THEN
  -- Be sure to process any single agent string one at a time without the need of a transaction or locking AgentString table
  PERFORM pg_advisory_lock(inString);
  INSERT INTO AgentString (agent,userAgentString) (
   SELECT inAgent, inString
   FROM Dual
   LEFT JOIN AgentString AS exists ON exists.userAgentString = inString
    AND ((exists.agent = inAgent) OR (exists.agent IS NULL AND inAgent IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inString);
 END IF;
 RETURN (
  SELECT id
  FROM AgentString
  WHERE userAgentString = inString
   AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- Consider https://github.com/ua-parser to parse the user agent string
-- Sessions without or before authentication
-- First check memory cache for a agent id before parsing and sending to this function.
-- If found then call AnonymousSession(agentString_id, device_agent_id, 0,'www.ibm.com',NULL,NULL, '107.77.97.52');
-- Using ClientDo as an example
-- SELECT AnonymousSession('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36','Chrome','43','0','2357','130','Linux',NULL,NULL,NULL,NULL,NULL,'Other',0,'www.ibm.com',NULL,NULL,'107.77.97.52');
CREATE OR REPLACE FUNCTION AnonymousSession (
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS bigint AS $$
DECLARE string_id INTEGER;
DECLARE deviceAgent_id INTEGER;
DECLARE deviceName VARCHAR;
DECLARE agentString_id INTEGER;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));

 deviceAgent_id = (SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion));

 agentString_id = (SELECT GetAgentString(deviceAgent_id, string_id));

 RETURN (
  SELECT AnonymousSession(agentString_id, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AnonymousSession (
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS bigint AS $$
BEGIN
 RETURN (
  SELECT AnonymousSession(inUAstring, inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild, inOSfamily, inOSmajor, inOSminor, inOSpatch, inDeviceBrand, inDeviceModel, inDeviceFamily, NULL, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress)
 );
END;
$$ LANGUAGE plpgsql;

-- SELECT AnonymousSession(1, 0,'www.ibm.com',NULL,NULL,'107.77.97.52');
CREATE OR REPLACE FUNCTION AnonymousSession (
 inAgentString INTEGER,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS bigint AS $$
DECLARE existingSession bigint;
DECLARE referringURL integer;
BEGIN

 referringURL := GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet);

 existingSession := (
  SELECT session
  FROM SessionCredential
  WHERE credential IS NULL
  AND agentString = inAgentString
  AND fromAddress = inIPAddress
  AND ((referring = referringURL) OR (referring IS NULL AND referringURL IS NULL))
  LIMIT 1
 );

 IF existingSession IS NULL THEN
  INSERT INTO Session (lock) VALUES (0) RETURNING id INTO existingSession;

  -- Associate a remote client and remote IP address to a session
  INSERT INTO SessionCredential (session,agentString,fromAddress,referring)
  SELECT existingSession AS session, inAgentString AS agentString,
   inIPAddress AS fromAddress, referringURL
  ;
 ELSE
  UPDATE Session SET touched = NOW() WHERE id = existingSession;
 END IF;

 RETURN existingSession;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION SetSession (
 inSession varchar,
 inSiteApplicationRelease integer,
 inCredential integer,
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersioin varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet,
 inLocation integer
) RETURNS bigint AS $$
BEGIN
 RETURN (SELECT SetSession(inSession,inSiteApplicationRelease,inCredential,inUAstring,inUAfamily,inUAmajor,inUAminor,inUApatch,inUAbuild,inOSfamily,inOSmajor,inOSminor,inOSpatch,inDeviceBrand,inDeviceModel,inDeviceFamily,inDeviceFamilyVersion,inRefSecure,inRefHost,inRefPath,inRefGet,inIPAddress,inLocation,NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inCredential integer,
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet,
 inLocation integer,
 inStart timestamp
) RETURNS bigint AS $$
DECLARE string_id INTEGER;
DECLARE deviceAgent_id INTEGER;
DECLARE deviceName VARCHAR;
DECLARE agentString_id INTEGER;
DECLARE referring_id INTEGER;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));

 deviceAgent_id = (SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion));

 agentString_id = (SELECT GetAgentString(deviceAgent_id, string_id));

 referring_id = (SELECT GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet));

 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, agentString_id, inCredential, referring_id, inIPAddress, inLocation, inStart));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inAgentString integer,
 inCredential integer,
 inReferring integer,
 inIPAddress inet,
 inLocation integer
) RETURNS bigint AS $$
BEGIN
 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, inAgentString, inCredential, inReferring, inIPAddress, inLocation, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inAgentString integer,
 inCredential integer,
 inReferring integer,
 inIPAddress inet,
 inLocation integer,
 inStart timestamp
) RETURNS bigint AS $$
DECLARE newSession bigint;
DECLARE existingSession bigint;
BEGIN
 IF inSessionToken IS NOT NULL THEN
  -- Does a session already exist for this token and site application release
  existingSession := (
   SELECT session
   FROM SessionToken
   WHERE token = inSessionToken
    AND (
     (siteApplicationRelease = inSiteApplicationRelease)
      OR (siteApplicationRelease IS NULL AND inSiteApplicationRelease IS NULL)
    )
   LIMIT 1
  );

  IF existingSession IS NULL THEN
   PERFORM pg_advisory_lock(hashtext(inSessionToken));
   INSERT INTO Session (lock) VALUES (0) RETURNING id INTO existingSession;
   INSERT INTO SessionToken (session,token,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created
   );
   PERFORM pg_advisory_unlock(hashtext(inSessionToken));
  ELSE
   UPDATE Session SET touched = NOW() WHERE id = existingSession;
  END IF;

  -- Be sure to process any single session credential one at a time without the need of a transaction or locking SessionCredential table
  PERFORM pg_advisory_lock(existingSession);
  INSERT INTO SessionCredential (session, agentString, credential, referring, fromAddress, location) (
   SELECT existingSession, inAgentString, inCredential, inReferring, inIPAddress, inLocation
   FROM Dual
   LEFT JOIN SessionCredential AS exists ON exists.session = existingSession
    AND ((agentString = inAgentString) OR (agentString IS NULL AND inAgentString IS NULL))
    AND ((credential = inCredential) OR (credential IS NULL AND inCredential IS NULL))
    AND ((referring = inReferring) OR (referring IS NULL AND inReferring IS NULL))
    AND ((fromAddress = inIPAddress) OR (fromAddress IS NULL AND inIPAddress IS NULL))
    AND ((location = inLocation) OR (location IS NULL AND inLocation IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(existingSession);

 END IF;
 RETURN existingSession;
END;
$$ LANGUAGE plpgsql;


-- DAG https://www.codeproject.com/Articles/22824/A-Model-to-Represent-Directed-Acyclic-Graphs-DAG-o
CREATE OR REPLACE FUNCTION AddEdge(v_start int, v_stop int) RETURNS integer AS $$
DECLARE
	v_id int;
BEGIN
	-- can't start and stop at the same place
	IF v_start = v_stop THEN
		RAISE NOTICE 'Start != Stop';
		RETURN NULL;
	END IF;

	-- detect duplicate
	PERFORM id FROM edge
	WHERE start = v_start
	AND stop = v_stop
	AND hops = 0;
	IF found THEN
		RAISE NOTICE 'Duplicate, (%,%) already exists',v_start,v_stop;
		RETURN NULL; -- found duplicate
	END IF;

	-- detect circular relation attempt
	PERFORM id FROM edge
	WHERE start = v_stop
	AND stop = v_start;
	IF found THEN
		RAISE NOTICE 'Circular relation rejected';
		RETURN NULL; -- found circular conflict
	END IF;

	-- insert 0 hop edge
	INSERT INTO edge (
		id,
		start, stop,
		entry, direct, exit)
	VALUES (
		nextval('edge_id_seq'),
		v_start,
		v_stop,
		currval('edge_id_seq'),
		currval('edge_id_seq'),
		currval('edge_id_seq')
	);

	v_id := currval('edge_id_seq');

	-- Connect graphs A (start) and B (stop) together
	-- Step 1: A's incoming edges to B
	INSERT INTO edge (
		start, stop,
		hops,
		entry, direct, exit)
	SELECT
		start,
		v_stop,
		hops + 1,
		id,
		v_id,
		v_id
	FROM edge
	WHERE stop = v_start;

	-- Step 2: A to B's outgoing edges
	INSERT INTO edge (
		start, stop,
		hops,
		entry, direct, exit)
	SELECT
		v_start,
		stop,
		hops + 1,
		v_id,
		v_id,
		id
	FROM edge
	WHERE start = v_stop;

	-- Step 3: A's incoming edges to the stop node of B's outgoing edges
	INSERT INTO edge (
		start, stop,
		hops,
		entry, direct, exit)
	SELECT
		A.start,
		B.stop,
		A.hops + B.hops + 2,
		A.id,
		v_id,
		B.id
	FROM edge A CROSS JOIN edge B
	WHERE A.stop = v_start
	AND B.start = v_stop;

	RETURN v_id;
END
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION RemoveEdge(v_start int, v_stop int) RETURNS integer AS $$
DECLARE
	v_id int;
	v_count int;
BEGIN
	-- detect if it actually exists
	SELECT id INTO v_id FROM edge
		WHERE start = v_start
		AND stop = v_stop
		AND hops = 0;
	IF found THEN
		-- continue processing
	ELSE
		RAISE NOTICE 'Relation (%,%) does not exists',v_start,v_stop;
		RETURN NULL;
	END IF;

	CREATE TEMPORARY TABLE purgeList (id int);

	-- Step 1: rows that were originally inserted for this direct edge
	INSERT INTO purgeList
		SELECT id
		FROM edge
		WHERE direct = v_id;

	-- Step 2: scan and find all dependent rows that are inserted after first
	LOOP
		INSERT INTO purgeList
		SELECT id FROM edge
		WHERE hops > 0
		AND (entry IN (SELECT id FROM purgeList)
			OR exit IN (SELECT id FROM purgeList))
		AND id NOT IN (SELECT id FROM purgeList);
		EXIT WHEN NOT found;
	END LOOP;

	-- count the records to be deleted and then delete them
	SELECT count(id) INTO v_count FROM purgeList;
	DELETE FROM edge
	WHERE id IN (SELECT id FROM purgeList);

	DROP TABLE purgeList;

	RETURN v_count;
END
$$ LANGUAGE plpgsql;

-- Can Return NULL
CREATE OR REPLACE FUNCTION GetVertex (
 inVertexName varchar
) RETURNS integer AS $$
BEGIN
 RETURN (
  SELECT vertex
  FROM VertexName
  WHERE VertexName.name = GetSentence(inVertexName)
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddEdgeName (
 inStart varchar,
 inStop  varchar
) RETURNS integer AS $$
DECLARE
 v_start integer;
 v_stop  integer;
BEGIN
 v_start := GetVertex(inStart);
 IF v_start IS NULL THEN
  INSERT INTO VertexName (name) VALUES (GetSentence(inStart)) RETURNING vertex INTO v_start;
 END IF;

 v_stop := GetVertex(inStop);
 IF v_stop IS NULL THEN
  INSERT INTO VertexName (name) VALUES (GetSentence(inStop)) RETURNING vertex INTO v_stop;
 END IF;

 RETURN AddEdge(v_start, v_stop);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION RemoveEdgeName (
 inStart varchar,
 inStop  varchar
) RETURNS integer AS $$
DECLARE
 v_start integer;
 v_stop  integer;
 v_count integer;
BEGIN
 v_start := GetVertex(inStart);
 v_stop  := GetVertex(inStop);

 IF v_start IS NOT NULL AND v_stop IS NOT NULL THEN
  v_count := (SELECT RemoveEdge(v_start, v_stop));
 END IF;

 RETURN v_count;
END
$$ LANGUAGE plpgsql;

-- Can return NULL
CREATE OR REPLACE FUNCTION GetIndividualVertex (
 inIndividual bigint,
 inVertex  integer
) RETURNS integer AS $$
BEGIN

 RETURN (
  SELECT VertexName.vertex
  FROM IndividualVertex
  JOIN VertexName ON VertexName.vertex = inVertex
  JOIN Edge ON Edge.start = inVertex
  WHERE IndividualVertex.individual = inIndividual
  ORDER BY Edge.hops ASC
  LIMIT 1
 );
END
$$ LANGUAGE plpgsql;

-- Can return NULL
CREATE OR REPLACE FUNCTION GetIndividualVertex (
 inIndividual bigint
) RETURNS integer AS $$
BEGIN

 RETURN (
  SELECT VertexName.vertex
  FROM IndividualVertex
  JOIN VertexName ON VertexName.vertex = IndividualVertex.vertex
  LEFT JOIN Edge ON Edge.start = IndividualVertex.vertex
  WHERE IndividualVertex.individual = inIndividual
  ORDER BY Edge.hops ASC
  LIMIT 1
 );
END
$$ LANGUAGE plpgsql;

-- Vertex without a name
CREATE OR REPLACE FUNCTION CreateVertex (
) RETURNS integer AS $$
DECLARE
 v_id integer;
BEGIN
 INSERT INTO VertexName (name) VALUES (NULL) RETURNING vertex INTO v_id;

 RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualVertex (
 inIndividual bigint,
 inType varchar
) RETURNS integer AS $$
DECLARE
 v_id integer;
 t_id integer;
BEGIN

 v_id := GetIndividualVertex(inIndividual);
 IF inType IS NOT NULL AND inType != '' THEN
  t_id := GetIdentifier(inType);
 END IF;

 -- Create no-name Vertex
 IF v_id IS NULL THEN
  v_id := CreateVertex();
  INSERT INTO IndividualVertex (individual, vertex, type) VALUES (inIndividual, v_id, t_id);
 END IF;

RETURN v_id;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION SetIndividualVertex (
 inIndividual bigint
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN SetIndividualVertex(inIndividual, NULL);
END
$$ LANGUAGE plpgsql;



-- Double Entry Accounting functions
--

-- Drop functions thas use JournalEntryResult
DROP FUNCTION IF EXISTS Book(varchar, float);
--
DROP TYPE IF EXISTS JournalEntryResult;
CREATE TYPE JournalEntryResult AS (
 journal INTEGER,
 entry INTEGER
);

--
-- Book single amounts into double entry Journal
CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount FLOAT
) RETURNS JournalEntryResult AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 -- Pickup book and journal to use
 SELECT book, journal
 INTO book_id, journal_id
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
 ;

 -- Get a new unique entry_id
 INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

 INSERT INTO JournalEntry (journal, book, entry,  account, credit, amount)
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  NOT increaseCredit AS credit,
  (inAmount * increaseCreditIncrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseCreditIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  increaseCredit AS credit,
  (inAmount * increaseDebitIncrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseDebitIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  NOT decreaseCredit AS credit,
  (inAmount * decreaseCreditDecrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseCreditDecrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  decreaseCredit AS credit,
  (inAmount * decreaseDebitDecrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseDebitDecrease IS NOT NULL
 ;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

-- Book and return new balances
CREATE OR REPLACE FUNCTION BookBalance (
 inBook varchar,
 inAmount FLOAT
) RETURNS TABLE (
 book integer,
 entry integer,
 account integer,
 nameId integer,
 name varchar,
 rightside boolean,
 type integer,
 typeName varchar,
 debit float,
 credit float
) AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 book_id := (
  SELECT BookName.book
  FROM BookName
  WHERE BookName.name = GetSentence(inBook)
  LIMIT 1
 );

 SELECT * INTO journal_id, entry_id FROM Book(inBook, inAmount);

 RETURN QUERY
  SELECT book_id AS book,
   entry_id AS entry,
   Transactions.account,
   AccountName.name AS nameId,
   Sentence.value AS name,
   AccountName.credit AS rightside,
   AccountName.type,
   Word.value AS typeName,
   SUM(Transactions.debit) AS debit,
   SUM(transactions.credit) AS credit
  FROM (
   SELECT JournalEntry.account,
    CASE WHEN NOT JournalEntry.credit THEN
     JournalEntry.amount
    END AS debit,
    CASE WHEN JournalEntry.credit THEN
     JournalEntry.amount
    END AS credit
   FROM JournalEntry
   WHERE JournalEntry.account IN (
    SELECT DISTINCT JournalEntry.account
    FROM JournalEntry
    WHERE JournalEntry.entry = entry_id
     AND posted IS NULL
   ) AND JournalEntry.posted IS NULL
  ) AS Transactions
  JOIN AccountName ON AccountName.account = Transactions.account
  JOIN Word ON Word.id = AccountName.type
   AND Word.culture = 1033
  JOIN Sentence ON Sentence.id = AccountName.name
   AND Sentence.culture = 1033
  GROUP BY Transactions.account, AccountName.name, AccountName.credit, AccountName.type, Word.value, Sentence.value
  ;
END;
$$ LANGUAGE plpgsql;


-- Inventory Movement
--
CREATE OR REPLACE FUNCTION CreateBill (
 inSupplier bigint,
 inConsignee bigint,
 inType varchar,
 inParent integer
) RETURNS integer AS $$
DECLARE
 bill_id integer;
BEGIN
 INSERT INTO Bill (supplier, consignee, type, parent) VALUES (inSupplier, inConsignee, GetWord(inType), inParent) RETURNING id INTO bill_id;

 RETURN bill_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CreateBill (
 inSupplier bigint,
 inConsignee bigint,
 inType varchar
) RETURNS integer AS $$
BEGIN
 RETURN CreateBill (inSupplier, inConsignee, inType, NULL);
END;
$$ LANGUAGE plpgsql;


-- Can return NULL
-- Gets the oldest of type
CREATE OR REPLACE FUNCTION GetOutstandingBill (
 inSupplier bigint,
 inConsignee bigint,
 inType varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT id
  FROM Bill
  WHERE supplier = inSupplier
   AND consignee = inConsignee
   AND type = GetWord(inType)
   AND received IS NULL
   AND loaded IS NULL
   AND clean IS NULL
   AND dirty IS NULL
  ORDER BY created ASC
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer,
 inFromCargo integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
 book_amount float;
BEGIN
 SELECT INTO cargo_id
  id AS cargo_id
 FROM Cargo
 WHERE bill = inBill
  AND assembly = inAssembly
  AND ((individualJob = inIndividualJob) OR (inIndividualJob IS NULL AND individualJob IS NULL))
  AND ((journal = inJournal) OR (inJournal IS NULL AND journal IS NULL))
  AND ((entry = inEntry) OR (inEntry IS NULL AND entry IS NULL))
 ORDER BY id DESC
 LIMIT 1
 ;

 IF inBook IS NULL THEN
  IF cargo_id IS NULL THEN
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT nextval('cargo_id_seq'),
    inBill,
    CASE WHEN inCount = 1 THEN
     NULL -- cargo record itself is a count of one unless overridden
    ELSE
     inCount
    END AS count,
    inAssembly,
    inIndividualJob,
    inJournal,
    inEntry
   FROM DUAL
   RETURNING id INTO cargo_id;
  ELSE
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT cargo_id,
    inBill,
    inCount,
    inAssembly,
    inIndividualJob,
    inJournal,
    inEntry
   FROM DUAL
   ;
  END IF;
 ELSE
  -- Book the current amount for the cargo
  book_amount := (
   SELECT totalPrice
   FROM LineItems
   WHERE line = inFromCargo
    AND ((part = inAssembly) OR (part IS NULL AND inAssembly IS NULL))
    -- Don't check individualJob since the default in LineItems may be newer
    -- Use the locked in individualJob from the inFromCargo's inIndividualJob
    AND totalPrice IS NOT NULL
   LIMIT 1
  );
  IF cargo_id IS NULL THEN
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT nextval('cargo_id_seq'),
    inBill,
    CASE WHEN inCount = 1 THEN
     NULL -- cargo record itself is a count of one unless overridden
    ELSE
     inCount
    END AS count,
    inAssembly,
    inIndividualJob,
    journal,
    entry
   FROM Book(inBook, book_amount)
   RETURNING id INTO cargo_id;
  ELSE
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT cargo_id,
    inBill,
    inCount,
    inAssembly,
    inIndividualJob,
    journal,
    entry
   FROM Book(inBook, book_amount)
   ;
  END IF;
 END IF;

 IF inFromCargo IS NOT NULL THEN
  -- Create Cargo State records
  INSERT INTO CargoState (cargo, toCargo, count, journal, entry)
  VALUES (inFromCargo, cargo_id, inCount, inJournal, inEntry);
 END IF;

 RETURN cargo_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer,
 inFromCargo integer
) RETURNS integer AS $$
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, inIndividualJob, inJournal, inEntry, inFromCargo, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, inIndividualJob, inJournal, inEntry, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, NULL, NULL, NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
BEGIN
IF inToBill IS NOT NULL THEN
 IF inItem IS NULL THEN
  -- Move all remaining cargo to inToBill
  -- Use AddCargo
  PERFORM AddCargo(inToBill,
   Cargo.assembly,
   SUM(COALESCE(Cargo.count, 1)) - (
    CASE WHEN CargoState.cargo IS NOT NULL THEN
     SUM(COALESCE(CargoState.count, 1))
    ELSE
     0
    END
   ),
   COALESCE(inIndividualJob, Cargo.individualJob),
   Cargo.journal,
   Cargo.entry,
   Cargo.id,
   inBook)
  FROM Cargo
  LEFT JOIN CargoState ON CargoState.cargo = Cargo.id
  WHERE Cargo.bill = inFromBill
  GROUP BY Cargo.id,
   Cargo.assembly,
   Cargo.individualJob,
   Cargo.journal,
   Cargo.entry,
   CargoState.cargo
  HAVING SUM(COALESCE(Cargo.count, 1)) - (
    CASE WHEN CargoState.cargo IS NOT NULL THEN
     SUM(COALESCE(CargoState.count, 1))
    ELSE
     0
    END
   ) > 0
  ;
 ELSE
  -- Move single item cargo to inToBill
  -- Allow any count, even if more than inFromBill has
  PERFORM AddCargo(inToBill,
   inItem,
   inCount,
   COALESCE(inIndividualJob, Cargo.individualJob),
   Cargo.journal,
   Cargo.entry,
   Cargo.id,
   inBook)
  FROM Cargo
  WHERE Cargo.bill = inFromBill
   AND Cargo.assembly = inItem
  GROUP BY Cargo.id,
   Cargo.assembly,
   Cargo.individualJob,
   Cargo.journal,
   Cargo.entry
  ;
 END IF;
END IF;
RETURN inToBill;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN MoveCargo(inFromBill, inToBill, inItem, inCount, inIndividualJob, NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float
) RETURNS integer AS $$
BEGIN
 RETURN MoveCargo(inFromBill, inToBill, inItem, inCount, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
 to_bill integer;
BEGIN
 to_bill := (
  SELECT id
  FROM Bill
  WHERE Bill.parent = inFromBill
  LIMIT 1
 );

 RETURN MoveCargo(inFromBill, to_bill, inItem, inCount, inIndividualJob, inBook);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer
) RETURNS integer AS $$
DECLARE
 to_bill integer;
BEGIN
 RETURN MoveCargoToChild(inFromBill, inItem, inCount, inIndividualJob, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float
) RETURNS integer AS $$
BEGIN
 RETURN MoveCargoToChild(inFromBill, inItem, inCount, NULL);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetSchedule (
 inScheduleName varchar
) RETURNS integer AS $$
DECLARE scheduleName_id integer;
DECLARE schedule_id integer;
BEGIN
 IF inScheduleName IS NOT NULL THEN
   scheduleName_id := GetSentence(inScheduleName);
   -- Be sure to process any single schedule one at a time without the need of a transaction or locking ScheduleName table
   PERFORM pg_advisory_lock(scheduleName_id);
   INSERT INTO ScheduleName (name) (
    SELECT scheduleName_id
    FROM DUAL
    LEFT JOIN ScheduleName AS exists ON exists.name = scheduleName_id
    WHERE exists.schedule IS NULL
    LIMIT 1
   ) RETURNING schedule INTO schedule_id;
   PERFORM pg_advisory_unlock(scheduleName_id);
   IF schedule_id IS NULL THEN
    schedule_id = (
     SELECT schedule
     FROM ScheduleName
     WHERE name = scheduleName_id
     LIMIT 1
    );
   END IF;
 END IF;
 RETURN schedule_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetJob (
 inJobName varchar
) RETURNS integer AS $$
DECLARE jobName_id integer;
DECLARE job_id integer;
BEGIN
 IF inJobName IS NOT NULL THEN
  jobName_id := GetSentence(inJobName);
  -- Be sure to process any single job one at a time without the need of a transaction or locking JobName table
  PERFORM pg_advisory_lock(jobName_id);
  INSERT INTO JobName (name) (
   SELECT jobName_id
   FROM DUAL
   LEFT JOIN JobName AS exists ON exists.name = jobName_id
   WHERE exists.job IS NULL
   LIMIT 1
  ) RETURNING job INTO job_id;
  PERFORM pg_advisory_unlock(jobName_id);
  IF job_id IS NULL THEN
   job_id = (
    SELECT job
    FROM JobName
    WHERE name = jobName_id
    LIMIT 1
   );
  END IF;
 END IF;
 RETURN job_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualJobSchedule (
 inIndividual bigint,
 inJob integer,
 inSchedule integer
) RETURNS integer AS $$
DECLARE individualJob_id integer;
BEGIN
 individualJob_id = (
  SELECT id
  FROM IndividualJob
  WHERE ((individual = inIndividual) OR (individual IS NULL AND inIndividual IS NULL))
   AND job = inJob
   AND schedule = schedule
   AND stop IS NULL
  LIMIT 1
 );
 IF individualJob_id IS NULL THEN
   INSERT INTO IndividualJob (id, individual, job, schedule)
   VALUES(nextval('individualjob_id_seq'), inIndividual, inJob, inSchedule)
   RETURNING id INTO individualJob_id;
 END IF;
 RETURN individualJob_id;
END;
$$ LANGUAGE plpgsql;


-- Schema Mgmt Functions
--
CREATE OR REPLACE FUNCTION SetSchemaVersion (
 inSchemaName varchar,
 inMajor varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE
 schema_id integer;
 version_id integer;
BEGIN
 IF inSchemaName IS NOT NULL THEN
  schema_id := (SELECT GetWord(inSchemaName));
  version_id := (SELECT GetVersion(inMajor, inMinor, inPatch));
 END IF;
 -- Always insert generating a build number
 INSERT INTO SchemaVersion (schema, version) VALUES (schema_id, version_id);
 RETURN (SELECT currval(pg_get_serial_sequence('schemaversion','build')));
END;
$$ LANGUAGE plpgsql;
