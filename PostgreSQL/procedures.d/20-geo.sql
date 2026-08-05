-- Geo / Addresses — Location Postal Address (diagram: addresses)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetLocation (
 lat float,
 long float,
 accuracy_code integer
) RETURNS integer AS $$
DECLARE
 inLatitude NUMERIC(10,7);
 inLongitude NUMERIC(11,7);
 lockID bigint;
 location_id integer;
BEGIN
 inLatitude := lat;
 inLongitude := long;

 IF lat IS NOT NULL AND long IS NOT NULL THEN
  SELECT id INTO location_id
  FROM Location
  WHERE parent IS NULL
   AND marquee IS NULL
   AND longitude = inLongitude
   AND latitude = inLatitude
   AND ((accuracy = accuracy_code) OR (accuracy IS NULL AND accuracy_code IS NULL))
   AND level = 1 -- Default level
   AND altitudeabovesealevel IS NULL
   AND area IS NULL
  LIMIT 1;
  IF location_id IS NULL THEN
   -- Convert latitude numeric(10,7) to a 64 bit integer for lock
   lockID := (inLatitude * 10000000)::bigint;
   -- Be sure to process any single latitude one at a time without the need of a transaction or locking the Location table
   PERFORM pg_advisory_lock(lockID);
   BEGIN
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
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lockID);
     RAISE;
   END;
   SELECT id INTO location_id
   FROM Location
   WHERE parent IS NULL
    AND marquee IS NULL
    AND longitude = inLongitude
    AND latitude = inLatitude
    AND ((accuracy = accuracy_code) OR (accuracy IS NULL AND accuracy_code IS NULL))
    AND level = 1 -- Default level
    AND altitudeabovesealevel IS NULL
    AND area IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN location_id;
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
 postal_id integer;
BEGIN
 countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(countrycode));
 city_id := (SELECT GetWord(city));
 statecode_id := (SELECT GetWord(statecode));
 state_id := (SELECT GetWord(state));
 county_id := GetWord(county);
 location_id := (SELECT GetLocation(lat,long,accuracy));
 -- Be sure to process any single zipcode one at a time without the need of a transaction or locking the Postal table
 SELECT id INTO postal_id
 FROM Postal
 -- Unique on country and code
 WHERE country = countrycode_id
  AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
  AND UPPER(Postal.code) = UPPER(zipcode)
 LIMIT 1;
 IF postal_id IS NULL THEN
  PERFORM pg_advisory_lock(hashtext(UPPER(zipcode)));
  BEGIN
  INSERT INTO Postal (country, code, state, stateabbreviation, county, city, location) (
   SELECT countrycode_id, zipcode, state_id, statecode_id, county_id, city_id, location_id
   FROM Dual
   LEFT JOIN Postal AS exists ON exists.country = countrycode_id
    AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
    AND UPPER(exists.code) = UPPER(zipcode)
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(UPPER(zipcode)));
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(hashtext(UPPER(zipcode)));
    RAISE;
  END;
  SELECT id INTO postal_id
  FROM Postal
  -- Unique on country and code
  WHERE country = countrycode_id
   AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
   AND UPPER(Postal.code) = UPPER(zipcode)
  LIMIT 1;
 END IF;
 RETURN postal_id;
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
  LEFT JOIN Location ON Location.id = Postal.location
  WHERE Postal.country = Country.id
   AND UPPER(Postal.code) = UPPER(zipcode)
  ORDER BY Location.accuracy ASC NULLS LAST, Postal.id DESC
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
  -- TODO Currently most accurate Postal Code from all countries
  SELECT Postal.id
  FROM Postal
  LEFT JOIN Location ON Location.id = Postal.location
  WHERE UPPER(Postal.code) = UPPER(zipcode)
  ORDER BY Location.accuracy ASC NULLS LAST, Postal.id DESC
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
 address_id integer;
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
   SELECT id INTO address_id
   FROM Address
   WHERE postal = zipcode_id
    AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
    AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
    AND UPPER(line1) = UPPER(street)
    AND line2 IS NULL
    AND line3 IS NULL
    AND line4 IS NULL
   LIMIT 1;
   IF address_id IS NULL THEN
    -- Be sure to process any single zipcode id one at a time without the need of a transaction or locking the Address table
    PERFORM pg_advisory_lock(zipcode_id);
    BEGIN
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
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(zipcode_id);
      RAISE;
    END;
    SELECT id INTO address_id
    FROM Address
    WHERE postal = zipcode_id
     AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
     AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
     AND UPPER(line1) = UPPER(street)
     AND line2 IS NULL
     AND line3 IS NULL
     AND line4 IS NULL
    LIMIT 1;
   END IF;
  END IF;
  RETURN address_id;
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
 address_id integer;
BEGIN
  -- Do not call GetPostal with nulls so that this will return addresses with location information
  zipcode_id := (SELECT GetPostal(zipcode));

  IF zipcode_id IS NOT NULL THEN
   SELECT id INTO address_id
   FROM Address
   WHERE postal = zipcode_id
    AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
    AND UPPER(line1) = UPPER(street)
    AND line2 IS NULL
    AND line3 IS NULL
    AND line4 IS NULL
   ORDER BY location
   LIMIT 1; -- pickup a location based address first
   IF address_id IS NULL THEN
    -- Be sure to process any single zipcode id one at a time without the need of a transaction or locking the Address table
    PERFORM pg_advisory_lock(zipcode_id);
    BEGIN
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
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(zipcode_id);
      RAISE;
    END;
    SELECT id INTO address_id
    FROM Address
    WHERE postal = zipcode_id
     AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
     AND UPPER(line1) = UPPER(street)
     AND line2 IS NULL
     AND line3 IS NULL
     AND line4 IS NULL
    ORDER BY location
    LIMIT 1; -- pickup a location based address first
   END IF;
  END IF;
 RETURN address_id;
END;
$$ LANGUAGE plpgsql;

