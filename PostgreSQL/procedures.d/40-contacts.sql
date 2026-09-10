-- Contacts — Email Phone Path (diagrams: individual_email, phones, individual_path)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetEmail (
 inUserName varchar,
 inPlus varchar,
 inHost varchar
) RETURNS integer AS $$
DECLARE
 email_id integer;
BEGIN
 IF inUserName IS NOT NULL AND inHost IS NOT NULL THEN
  SELECT id INTO email_id
  FROM Email
  WHERE UPPER(username) = UPPER(inUserName)
   AND UPPER(host) = UPPER(inHost)
   AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
  LIMIT 1;
  IF email_id IS NULL THEN
   -- Be sure to process any single username one at a time without the need of a transaction or locking Email table
   PERFORM pg_advisory_lock(hashtext(inUserName));
   BEGIN
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
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inUserName));
     RAISE;
   END;
   SELECT id INTO email_id
   FROM Email
   WHERE UPPER(username) = UPPER(inUserName)
    AND UPPER(host) = UPPER(inHost)
    AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN email_id;
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
  BEGIN
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
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inIndividual_id);
    RAISE;
  END;
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

CREATE OR REPLACE FUNCTION SetIndividualPath (
 inIndividual bigint,
 inType varchar,
 inPath bigint
) RETURNS bigint AS $$
DECLARE
 type_id integer;
BEGIN
 IF inIndividual IS NOT NULL
  AND inPath IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  -- Be sure to process any single individual path one at a time without the need of a transaction or locking IndividualPath table
  PERFORM pg_advisory_lock(inIndividual);
  BEGIN
  INSERT INTO IndividualPath (individual, type, path) (
   SELECT inIndividual, type_id, inPath
   FROM Dual
   LEFT JOIN IndividualPath AS exists ON exists.individual = inIndividual
    AND exists.path = inPath
    AND ((exists.type = type_id) OR (exists.type IS NULL AND type_id IS NULL))
    AND exists.stop IS NULL
   WHERE exists.individual IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inIndividual);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inIndividual);
    RAISE;
  END;
 END IF;
 RETURN inIndividual;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopIndividualPath (
 inIndividual bigint,
 inType varchar,
 inPath bigint
) RETURNS bigint AS $$
DECLARE
 type_id integer;
BEGIN
 IF inIndividual IS NOT NULL
  AND inPath IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  PERFORM pg_advisory_lock(inIndividual);
  BEGIN
  UPDATE IndividualPath
  SET stop = NOW()
  WHERE individual = inIndividual
   AND path = inPath
   AND stop IS NULL
   AND ((type = type_id) OR (type IS NULL AND type_id IS NULL));
  PERFORM pg_advisory_unlock(inIndividual);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inIndividual);
    RAISE;
  END;
 END IF;
 RETURN inIndividual;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetPathPassword (
 inPath bigint,
 inPassword integer
) RETURNS bigint AS $$
BEGIN
 IF inPath IS NOT NULL
  AND inPassword IS NOT NULL THEN
  -- Be sure to process any single path password one at a time without the need of a transaction or locking PathPassword table
  PERFORM pg_advisory_lock(inPath);
  BEGIN
  INSERT INTO PathPassword (path, password) (
   SELECT inPath, inPassword
   FROM Dual
   LEFT JOIN PathPassword AS exists ON exists.path = inPath
    AND exists.password = inPassword
    AND exists.revoked IS NULL
   WHERE exists.path IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inPath);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inPath);
    RAISE;
  END;
 END IF;
 RETURN inPath;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION RevokePathPassword (
 inPath bigint,
 inPassword integer
) RETURNS bigint AS $$
BEGIN
 IF inPath IS NOT NULL
  AND inPassword IS NOT NULL THEN
  PERFORM pg_advisory_lock(inPath);
  BEGIN
  UPDATE PathPassword
  SET revoked = NOW()
  WHERE path = inPath
   AND password = inPassword
   AND revoked IS NULL;
  PERFORM pg_advisory_unlock(inPath);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inPath);
    RAISE;
  END;
 END IF;
 RETURN inPath;
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

CREATE OR REPLACE FUNCTION GetPath (
 inProtocol varchar,
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar,
 inPort integer
) RETURNS integer AS $$
DECLARE
 is_secure integer := 0;
 port_value integer;
 lockText varchar;
 lockID bigint;
 path_id integer;
BEGIN
 -- host and path can not both be null
 IF inValue IS NOT NULL OR inHost IS NOT NULL THEN
  -- Default to false or 0
  IF inSecure IS NOT NULL AND inSecure != 0 THEN
    is_secure :=1;
  END IF;
  lockText := COALESCE(inHost, '') || COALESCE(inPort::text, '') || COALESCE(inValue, '');
  lockID := hashtext(lockText);
  IF is_secure = 0 AND inPort != 80 THEN port_value := inPort; END IF;
  IF is_secure = 1 AND inPort != 443 THEN port_value := inPort; END IF;
  SELECT id INTO path_id
  FROM Path
  WHERE protocol = inProtocol
   AND secure = is_secure
   AND ((UPPER(host) = UPPER(inHost)) OR (host IS NULL and inHost IS NULL))
   AND ((port = port_value) OR (port IS NULL AND port_value IS NULL))
   AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
   AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
  LIMIT 1;
  IF path_id IS NULL THEN
   -- Be sure to process any single path one at a time without the need of a transaction or locking Path table
   PERFORM pg_advisory_lock(lockID);
   BEGIN
   INSERT INTO Path (protocol, secure, host, port, value, get) (
    SELECT inProtocol, is_secure, inHost, port_value, inValue, inGet
    FROM Dual
    LEFT JOIN Path AS exists ON exists.protocol = inProtocol
     AND exists.secure = is_secure
     AND ((UPPER(exists.host) = UPPER(inHost)) OR (exists.host IS NULL AND inHost IS NULL))
     AND ((exists.port = port_value) OR (exists.port IS NULL AND port_value IS NULL))
     AND ((exists.value = inValue) OR (exists.value IS NULL OR inValue IS NULL))
     AND ((exists.get = inGet) OR (exists.get IS NULL AND inGet IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(lockID);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lockID);
     RAISE;
   END;
   SELECT id INTO path_id
   FROM Path
   WHERE protocol = inProtocol
    AND secure = is_secure
    AND ((UPPER(host) = UPPER(inHost)) OR (host IS NULL and inHost IS NULL))
    AND ((port = port_value) OR (port IS NULL AND port_value IS NULL))
    AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
    AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN path_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPath (
 inProtocol varchar,
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetPath(inProtocol, inSecure, inHost, inValue, inGet, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetURL (
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar,
 inPort integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetPath('http', inSecure, inHost, inValue, inGet, inPort));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetURL (
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetURL(inSecure, inHost, inValue, inGet, NULL));
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
 phone_id integer;
BEGIN
 IF inNumber IS NOT NULL THEN
  countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(inCountryCode));
  IF countrycode_id IS NOT NULL THEN
   SELECT id INTO phone_id
   FROM Phone
   WHERE country = countrycode_id
    AND area = inAreaCode
    AND number = inNumber
   LIMIT 1;
   IF phone_id IS NULL THEN
    -- Be sure to process any single phone number one at a time without the need of a transaction or locking Phone table
    PERFORM pg_advisory_lock(hashtext(inNumber));
    BEGIN
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
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(hashtext(inNumber));
      RAISE;
    END;
    SELECT id INTO phone_id
    FROM Phone
    WHERE country = countrycode_id
     AND area = inAreaCode
     AND number = inNumber
    LIMIT 1;
   END IF;
  END IF;
 END IF;
 RETURN phone_id;
END;
$$ LANGUAGE plpgsql;


-- For examples only.  Don't use in a production environment
