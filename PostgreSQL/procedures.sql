CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 INSERT INTO Word (value, culture) (
  SELECT word_value, Culture.code
  FROM Culture
  LEFT JOIN Word AS exists ON UPPER(exists.value) = UPPER(word_value)
   AND exists.culture = Culture.code
  WHERE UPPER(Culture.name) = UPPER(culture_name)
   AND exists.id IS NULL
 );
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
BEGIN
 INSERT INTO Location (latitude, longitude, accuracy) (
  SELECT lat, long, accuracy
  FROM Dual
  LEFT JOIN Location AS exists ON exists.latitude = lat
   AND exists.longitude = long
   AND ((exists.accuracy = accuracy_code) OR (exists.accuracy IS NULL AND accuracy_code IS NULL))
  WHERE exists.id IS NULL
 );
 RETURN (
  SELECT id
  FROM Location
  WHERE parent IS NULL
   AND marquee IS NULL
   AND longitude = long
   AND latitude = lat
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

 -- Get location
 location_id := (SELECT GetLocation(lat,long,accuracy));

 INSERT INTO Postal (country, code, state, stateabbreviation, county, city, location) (
  SELECT countrycode_id, zipcode, state_id, statecode_id, county_id, city_id, location_id
  FROM Dual
  LEFT JOIN Postal AS exists ON exists.country = countrycode_id
   AND UPPER(exists.code) = UPPER(zipcode)
   AND exists.state = state_id
   AND exists.stateabbreviation = statecode_id
   AND exists.county = county_id
   AND exists.city = city_id
   AND exists.location = location_id
  WHERE exists.id IS NULL
 );
 RETURN (
  SELECT id
  FROM Postal
  WHERE country = countrycode_id
   AND UPPER(Postal.code) = UPPER(zipcode)
   AND Postal.state = state_id
   AND Postal.stateabbreviation = statecode_id
   AND Postal.county = county_id
   AND Postal.city = city_id
   AND Postal.location = location_id
 );
END;
$$ LANGUAGE plpgsql;

