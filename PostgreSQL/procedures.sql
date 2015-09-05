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

-- Identifiers are normally by convention en-US based names used in programming and protocols
-- Return the Id of an identifier
-- It is inserted if it does not already exist
CREATE OR REPLACE FUNCTION GetIdentifier (
 ident_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF ident_value IS NOT NULL THEN
  INSERT INTO Word (value, culture) (
   SELECT ident_value, NULL
   FROM Dual
   LEFT JOIN Word AS exists ON UPPER(exists.value) = UPPER(ident_value)
    AND exists.culture IS NULL
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Word
  WHERE UPPER(Word.value) = UPPER(ident_value)
   AND Word.culture IS NULL
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIdentityPhrase (
 phrase_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF phrase_value IS NOT NULL THEN
  INSERT INTO Sentence (value, culture) (
   SELECT phrase_value, NULL
   FROM Dual
   LEFT JOIN Sentence AS exists ON UPPER(exists.value) = UPPER(phrase_value)
    AND exists.culture IS NULL
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Sentence
  WHERE UPPER(Sentence.value) = UPPER(phrase_value)
   AND Sentence.culture IS NULL
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

CREATE OR REPLACE FUNCTION GetEmail (
 inEmail varchar
) RETURNS integer AS $$
DECLARE
 userHostSplit varchar[];  -- Remeber these start at 1 not 0
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
 inListName varchar,
 inSetName varchar,
 inIndividual integer
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
 inListName varchar,
 inIndividual integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListSubscribe(inListName, NULL, inIndividual));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual integer
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
 inListName varchar,
 inIndividual integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListUnSubscribe(inListName, NULL, inIndividual));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CreateIndividual (
) RETURNS integer AS $$
DECLARE
BEGIN
 INSERT INTO Individual (birth) VALUES(NULL);
 RETURN (SELECT currval(pg_get_serial_sequence('individual','id')));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id integer,
 inEmail_id integer
) RETURNS void AS $$
DECLARE
BEGIN
 IF inIndividual_id IS NOT NULL
  AND inEmail_id IS NOT NULL THEN
  INSERT INTO IndividualEmail (individual, email) (
   SELECT inIndividual_id, inEmail_id
   FROM DUAL
   LEFT JOIN IndividualEmail AS exists ON exists.individual = inIndividual_id
    AND exists.email = inEmail_id
    AND exists.stop IS NULL
   WHERE exists.individual IS NULL
  );
 END IF;
END;
$$ LANGUAGE plpgsql;

-- Get Individual associated with an email
CREATE OR REPLACE FUNCTION GetIndividualEmail (
  inEmail varchar
) RETURNS integer AS $$
DECLARE
 email_id integer;
 individual_id integer;
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
 individual_id integer;
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
  INSERT INTO Version (major, minor, patch) (
   SELECT major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS exists ON exists.major = major_id
    AND ((exists.minor = minor_id) OR (exists.minor IS NULL AND minor_id IS NULL))
    AND ((exists.patch = patch_id) OR (exists.patch IS NULL AND patch_id IS NULL))
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE major = major_id
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
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
  INSERT INTO Version (name, major, minor, patch) (
   SELECT name_id, major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS exists ON exists.name = name_id
    AND ((exists.major = major_id) OR (exists.major IS NULL AND major_id IS NULL))
    AND ((exists.minor = minor_id) OR (exists.minor IS NULL AND minor_id IS NULL))
    AND ((exists.patch = patch_id) OR (exists.patch IS NULL AND patch_id IS NULL))
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE name= name_id
   AND ((major = major_id) OR (major IS NULL AND major_id IS NULL))
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
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
  build_id := (SELECT GetIdentifier(inBuild));
  INSERT INTO Release (build, version) (
   SELECT build_id AS build, inVersion AS version
   FROM Dual
   LEFT JOIN Release AS exists ON exists.version = inVersion
    AND ((exists.build = build_id) OR (exists.build IS NULL AND build_id IS NULL)) 
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Release
  WHERE version = inVersion
   AND ((build = build_id) OR (build IS NULL AND build_id IS NULL))
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
  name_ident := (SELECT GetIdentifier(inName));
  INSERT INTO Application (name) (
   SELECT name_ident AS name
   FROM Dual
   LEFT JOIN Application AS exists ON exists.name = name_ident
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Application
  WHERE name = name_ident
 );
END;
$$ LANGUAGE plpgsql;

-- GetApplicationRelease(application integer, release integer)
CREATE OR REPLACE FUNCTION GetApplicationRelease (
 inApplication integer,
 inRelease integer
) RETURNS integer AS $$
BEGIN
 IF inApplication IS NOT NULL AND inRelease IS NOT NULL THEN
  INSERT INTO ApplicationRelease (application, release) (
   SELECT inApplication AS application, inRelease AS release
   FROM Dual
   LEFT JOIN ApplicationRelease AS exists ON exists.application = inApplication
    AND exists.release = inRelease
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM ApplicationRelease
  WHERE application = inApplication
   AND release = inRelease
 );
END;
$$ LANGUAGE plpgsql;

-- GetPart(name varchar)
CREATE OR REPLACE FUNCTION GetPart (
 inName varchar
) RETURNS integer AS $$
DECLARE name_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetWord(inName));
  INSERT INTO Part (name) (
   SELECT name_id
   FROM Dual
   LEFT JOIN Part AS exists ON exists.name = name_id
    AND exists.parent IS NULL
    AND exists.version IS NULL
    AND exists.serial IS NULL
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent IS NULL
   AND version IS NULL
   AND serial IS NULL
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAssemblyApplicationRelease (
 inAssembly integer,
 inApplicationRelease integer,
 inParent integer
) RETURNS integer AS $$
BEGIN
 IF inAssembly IS NOT NULL AND inApplicationRelease IS NOT NULL THEN
  INSERT INTO AssemblyApplicationRelease (parent, assembly, applicationRelease) (
   SELECT inParent AS parent, inAssembly AS assembly, inApplicationRelease AS applicationRelease
   FROM Dual
   LEFT JOIN AssemblyApplicationRelease AS exists ON exists.assembly = inAssembly
    AND exists.applicationRelease = inApplicationRelease
    AND ((exists.parent = inParent) OR (exists.parent IS NULL AND inParent IS NULL))
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM AssemblyApplicationRelease
  WHERE assembly = inAssembly
   AND applicationRelease = inApplicationRelease
   AND ((parent = inParent) OR (parent IS NULL AND inParent IS NULL))
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAssemblyApplicationRelease (
 inAssembly integer,
 inApplicationRelease integer
) RETURNS integer AS $$
BEGIN
RETURN (SELECT id FROM GetAssemblyApplicationRelease(inAssembly, inApplicationRelease, NULL) AS id);
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
BEGIN
 -- host and path can not both be null
 IF inValue IS NOT NULL OR inHost IS NOT NULL THEN
  -- Default to false or 0
  IF inSecure IS NOT NULL AND inSecure != 0 THEN
    is_secure :=1;
  END IF;
  INSERT INTO Path (protocol, secure, host, value, get) (
   SELECT inProtocol, is_secure, inHost, inValue, inGet
   FROM Dual
   LEFT JOIN Path AS exists ON exists.protocol = inProtocol
    AND exists.secure = is_secure
    AND ((UPPER(exists.host) = UPPER(inHost)) OR (exists.host IS NULL AND inHost IS NULL))
    AND ((exists.value = inValue) OR (exists.value IS NULL OR inValue IS NULL))
    AND ((exists.get = inGet) OR (exists.get IS NULL AND inGet IS NULL))
   WHERE exists.id IS NULL
  );
 END IF;
 RETURN (
  SELECT id
  FROM Path
  WHERE protocol = inProtocol
   AND secure = is_secure
   AND ((UPPER(host) = UPPER(inHost)) OR (host IS NULL and inHost IS NULL))
   AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
   AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
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
 RETURN (SELECT id FROM GetPath('http', inSecure, inHost, inValue, inGet) AS id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFile (
 inHost varchar,
 inPathValue varchar,
 inFileGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT id FROM GetPath('file', 0, inHost, inPathValue, inFileGet) AS id);
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

-- Consider https://github.com/ua-parser to parse the user agent string
-- Sessions without or before authentication
-- First check memory cache for a agent id before parsing and sending to this function.
-- If found then call AnonymousSession(agentString_id, device_agent_id, 0,'www.ibm.com',NULL,NULL, '107.77.97.52');
-- Using ClientDo as an example
-- SELECT * FROM AnonymousSession('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36','Chrome','43','0','2357','130','Linux',NULL,NULL,NULL,NULL,NULL,'Other',0,'www.ibm.com',NULL,NULL,'107.77.97.52');
CREATE OR REPLACE FUNCTION AnonymousSession (
 -- User Agent
 inUAstring varchar,
 inUA varchar,
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
) RETURNS varchar AS $$
DECLARE agentString_id INTEGER;
DECLARE deviceAgent_id INTEGER;
DECLARE deviceName VARCHAR;
BEGIN
 agentString_id := (SELECT id FROM GetIdentityPhrase(inUAstring) AS id);

 deviceName := (SELECT COALESCE(inDeviceFamily, 'Unknown'));
 -- User Device Agent SessionCredential.agent field, references AssemblyApplicationRelease.id
 deviceAgent_id = (
  SELECT id
  FROM GetAssemblyApplicationRelease(
   -- device
   GetPart(deviceName),
   -- application release id
   GetApplicationRelease(
    -- application id
    GetApplication(inUA),
    -- application release
    GetRelease(
     -- application version
     GetVersion(inUAmajor,inUAminor,inUApatch),
     inUAbuild)
   ),
   -- device os
   GetAssemblyApplicationRelease(
    --device
    GetPart(deviceName),
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
  ) AS id
 );

 RETURN (
  SELECT id FROM AnonymousSession(agentString_id, deviceAgent_id, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress) AS id
 );
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM AnonymousSession(2000000, 10001, 0,'www.ibm.com',NULL,NULL,'107.77.97.52');
CREATE OR REPLACE FUNCTION AnonymousSession (
 inAgentStringId INTEGER,
 inDeviceAgent INTEGER,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS varchar AS $$
DECLARE newSession VARCHAR;
BEGIN

 newSession = (SELECT session FROM RandomString(32) AS session);
 INSERT INTO Session (id) VALUES(newSession);

 -- Associate a remote client and remote IP address to a session
 INSERT INTO SessionCredential (session,agentString,agent,fromAddress,referring)
 SELECT newSession AS session, inAgentStringId AS agentString,
  inDeviceAgent AS agent, inIPAddress AS fromAddress, 
  -- referring url
  GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet)
 ;

 RETURN newSession;
END;
$$ LANGUAGE plpgsql;



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
