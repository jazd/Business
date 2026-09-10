-- =============================================================================
-- Business schema upgrade: 0.2.10 -> 0.2.11 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.11 is unreleased. Keep this file in sync with
-- develop (procedures.d, schema.xml, post.sql, Static seeds) so a database
-- installed at 0.2.10 can reach the same end state as a fresh 0.2.11 build.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.10 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.10-0.2.11.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.10 database)
-- ---------------------------------------------------------------------------
--
--  1) Bill.shipfrom / Bill.shipto + Address FKs; Location id sequence
--  2) Wider Email.host, Path.host, SessionToken.token; Path.port
--  3) URL and IndividualURL include :port when Path.port is set
--  4) GetPath / GetURL overloads with inPort (default-port stored as NULL)
--  5) SessionToken.type; SetSession inType overloads; Word 18-20 session/mail/trial
--  6) SetSession writes IndividualSessionCreated when inCredential has an individual
--  7) IndividualSessions view (current individual to session across sites)
--  8) SetIndividualPath / StopIndividualPath; unique active (individual, type, path)
--  9) SessionPath table; SetSessionPath / StopSessionPath; unique active
--     (session, type, path); SessionURL view
-- 10) ClaimSession (session id or token + email); credential + SetSession +
--     copy unstopped SessionPath to IndividualPath
-- 11) PathPassword; SetPathPassword / RevokePathPassword; unique unrevoked
--     (path, password)
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '11') - last substantive step
--
-- TESTING
--   * make pgsqldb on develop (fresh 0.2.11-shaped DB)
--   * Upgrade a copy of a 0.2.10 production/test DB with this script
--   * BusinessSchema.PostgreSqlSuite (~24 intentional exceptions on
--     XcepteionRequired)
--
-- =============================================================================
\set ON_ERROR_STOP on

DO $$
BEGIN
 IF NOT EXISTS (
  SELECT true
  FROM pg_namespace
  WHERE nspname = 'business'
 ) THEN
  RAISE EXCEPTION 'Schema "Business" does not exist in this database';
 END IF;

 SET search_path TO business, public;

 IF NOT EXISTS (
  SELECT true
  FROM schemaversion
  JOIN word AS schema ON schema.id = schemaversion.schema
  JOIN version ON version.id = schemaversion.version
  JOIN word AS major ON major.id = version.major
  JOIN word AS minor ON minor.id = version.minor
  JOIN word AS patch ON patch.id = version.patch
  WHERE schema.value = 'Business'
   AND major.value = '0'
   AND minor.value = '2'
   AND patch.value = '10'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.10';
 END IF;

END $$;

SET search_path TO business, public;

-- ---------------------------------------------------------------------------
-- 0.2.11: Bill ship addresses; Location id sequence
-- ---------------------------------------------------------------------------

ALTER TABLE Bill ADD COLUMN shipfrom integer;
ALTER TABLE Bill ADD COLUMN shipto integer;
ALTER TABLE Bill ADD CONSTRAINT bill_address_from FOREIGN KEY (shipfrom) REFERENCES Address (id) DEFERRABLE;
ALTER TABLE Bill ADD CONSTRAINT bill_address_to FOREIGN KEY (shipto) REFERENCES Address (id) DEFERRABLE;

SELECT setval('location_id_seq', 20000, false);
--^^--

-- ---------------------------------------------------------------------------
-- 0.2.11: Email/Path host widths, SessionToken.token, Path.port
-- ---------------------------------------------------------------------------
-- Widen in place (existing values fit the old lengths). Path.port stays NULL
-- on existing rows: GetPath treats NULL as 80 when insecure and 443 when
-- secure. Do not backfill 80/443.

ALTER TABLE Email ALTER COLUMN host TYPE varchar(96);
ALTER TABLE Path ALTER COLUMN host TYPE varchar(96);
ALTER TABLE SessionToken ALTER COLUMN token TYPE varchar(128);
ALTER TABLE Path ADD COLUMN IF NOT EXISTS port smallint;

-- ---------------------------------------------------------------------------
-- 0.2.11: URL views (port in concatenated value; column list unchanged)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW URL AS
SELECT id AS path, protocol, host,
 protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host ||
 CASE WHEN port IS NOT NULL THEN ':' || port ELSE '' END ||
 '/' ||
 COALESCE(value,'') ||
 CASE WHEN get IS NULL
 THEN ''
 ELSE '?' || get
 END AS value,
 created
FROM Path;

CREATE OR REPLACE VIEW IndividualURL AS
WITH latest (individual,type,created) AS (
 SELECT individual, type, MAX(created) AS created
 FROM IndividualPath
 WHERE IndividualPath.stop IS NULL
 GROUP BY individual, type
)
SELECT latest.individual, latest.type, Path.id AS path, Path.protocol, Path.host,
 Path.protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host ||
 CASE WHEN port IS NOT NULL THEN ':' || port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,IndividualPath.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND IndividualPath.track IS NOT  NULL) THEN '&' ELSE '' END ||  IndividualPath.track, '')
 END AS value,
 latest.created
FROM latest
JOIN IndividualPath ON IndividualPath.individual = latest.individual
 AND IndividualPath.type = latest.type
 AND IndividualPath.created = latest.created
JOIN Individual ON Individual.id = latest.individual
 AND Individual.nameChange IS NULL
JOIN Path ON Path.id = IndividualPath.path;

-- ---------------------------------------------------------------------------
-- 0.2.11: GetPath / GetURL port overloads (from procedures.d/40-contacts.sql)
-- ---------------------------------------------------------------------------
-- New 6-arg GetPath and 5-arg GetURL; existing 5-arg GetPath and 4-arg GetURL
-- become wrappers (port NULL). GetFile keeps calling 5-arg GetPath.

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

-- ---------------------------------------------------------------------------
-- 0.2.11: SessionToken.type and SetSession inType overloads
-- ---------------------------------------------------------------------------
-- Existing SessionToken rows keep type NULL (schema: NULL means session).
-- Do not backfill Word 18 onto old rows.

ALTER TABLE SessionToken ADD COLUMN IF NOT EXISTS type integer;

INSERT INTO Word (id, culture, value)
SELECT 18, 1033, 'session'
WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id = 18 AND culture = 1033);

INSERT INTO Word (id, culture, value)
SELECT 19, 1033, 'mail'
WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id = 19 AND culture = 1033);

INSERT INTO Word (id, culture, value)
SELECT 20, 1033, 'trial'
WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id = 20 AND culture = 1033);

-- Core writer first (new 9-arg). Then wrappers: old 8-arg, UA with type, UA without type.

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inAgentString integer,
 inCredential integer,
 inReferring integer,
 inIPAddress inet,
 inLocation integer,
 inStart timestamp,
 inType varchar
) RETURNS bigint AS $$
DECLARE
 newSession bigint;
 existingSession bigint;
 type_id integer;
 session_credential_id bigint;
BEGIN
 IF inSessionToken IS NOT NULL THEN
  type_id = (SELECT GetWord(inType));
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
   BEGIN
   INSERT INTO Session (lock) VALUES (0) RETURNING id INTO existingSession;
   INSERT INTO SessionToken (session,token,type,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, type_id, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created
   );
   PERFORM pg_advisory_unlock(hashtext(inSessionToken));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inSessionToken));
     RAISE;
   END;
  ELSE
   UPDATE Session SET touched = NOW() WHERE id = existingSession;
  END IF;

  -- Be sure to process any single session credential one at a time without the need of a transaction or locking SessionCredential table
  PERFORM pg_advisory_lock(existingSession);
  BEGIN
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
  SELECT id INTO session_credential_id
  FROM SessionCredential
  WHERE session = existingSession
   AND ((agentString = inAgentString) OR (agentString IS NULL AND inAgentString IS NULL))
   AND ((credential = inCredential) OR (credential IS NULL AND inCredential IS NULL))
   AND ((referring = inReferring) OR (referring IS NULL AND inReferring IS NULL))
   AND ((fromAddress = inIPAddress) OR (fromAddress IS NULL AND inIPAddress IS NULL))
   AND ((location = inLocation) OR (location IS NULL AND inLocation IS NULL))
  LIMIT 1;
  IF inCredential IS NOT NULL AND session_credential_id IS NOT NULL THEN
   INSERT INTO IndividualSessionCreated (individual, sessionCredential) (
    SELECT cred.individual, session_credential_id
    FROM Credential AS cred
    LEFT JOIN IndividualSessionCreated AS exists
     ON exists.individual = cred.individual
     AND exists.sessionCredential = session_credential_id
    WHERE cred.id = inCredential
     AND cred.individual IS NOT NULL
     AND exists.individual IS NULL
    LIMIT 1
   );
  END IF;
  PERFORM pg_advisory_unlock(existingSession);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(existingSession);
    RAISE;
  END;

 END IF;
 RETURN existingSession;
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
BEGIN
 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, inAgentString, inCredential, inReferring, inIPAddress, inLocation, inStart, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inCredential integer,
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar,
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 inIPAddress inet,
 inLocation integer,
 inStart timestamp,
 inType varchar
) RETURNS bigint AS $$
DECLARE
 string_id INTEGER;
 deviceAgent_id INTEGER;
 deviceName VARCHAR;
 agentString_id INTEGER;
 referring_id INTEGER;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));

 deviceAgent_id = (SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion));

 agentString_id = (SELECT GetAgentString(deviceAgent_id, string_id));

 referring_id = (SELECT GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet));

 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, agentString_id, inCredential, referring_id, inIPAddress, inLocation, inStart, inType));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inCredential integer,
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar,
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 inIPAddress inet,
 inLocation integer,
 inStart timestamp
) RETURNS bigint AS $$
BEGIN
 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, inCredential, inUAstring, inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild, inOSfamily, inOSmajor, inOSminor, inOSpatch, inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress, inLocation, inStart, NULL));
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 0.2.11: IndividualSessions (current individual to session, all sites)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW IndividualSessions AS
WITH bound (individual, sessionCredential, bound) AS (
 SELECT individual, sessionCredential, created
 FROM IndividualSessionCreated
 UNION
 SELECT Credential.individual, SessionCredential.id, SessionCredential.created
 FROM SessionCredential
 JOIN Credential ON Credential.id = SessionCredential.credential
  AND Credential.revoked IS NULL
  AND Credential.individual IS NOT NULL
)
SELECT
 bound.individual,
 COALESCE(People.fullName, Entities.name) AS individualName,
 Session.id AS session,
 SessionToken.token,
 Type.value AS tokenType,
 SessionToken.siteApplicationRelease,
 Site.id AS site,
 SessionCredential.id AS sessionCredential,
 SessionCredential.credential,
 Credential.username,
 EmailAddress.value AS email,
 bound.bound,
 Session.touched,
 COALESCE(SessionToken.created, Session.created) AS created
FROM bound
JOIN SessionCredential ON SessionCredential.id = bound.sessionCredential
JOIN Session ON Session.id = SessionCredential.session
JOIN Credential ON Credential.id = SessionCredential.credential
 AND Credential.revoked IS NULL
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN I18NWord AS Type ON Type.id = SessionToken.type
LEFT JOIN SiteApplicationRelease ON SiteApplicationRelease.id = SessionToken.siteApplicationRelease
LEFT JOIN Site ON Site.id = SiteApplicationRelease.site
LEFT JOIN People ON People.individual = bound.individual
LEFT JOIN Entities ON Entities.individual = bound.individual
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email;

-- ---------------------------------------------------------------------------
-- 0.2.11: SetIndividualPath / StopIndividualPath
-- ---------------------------------------------------------------------------
-- Append an unstopped (individual, type, path) if missing. Stop sets stop on
-- that current row only (does not stop other paths of the same type).

CREATE UNIQUE INDEX IF NOT EXISTS individualPath_individual_type_path_unstopped
 ON IndividualPath (individual, type, path)
 WHERE stop IS NULL;

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

-- ---------------------------------------------------------------------------
-- 0.2.11: SessionPath, SetSessionPath / StopSessionPath, SessionURL
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS SessionPath (
 session bigint NOT NULL,
 type integer,
 path bigint,
 track varchar(30),
 stop timestamp,
 created timestamp NOT NULL DEFAULT NOW(),
 CONSTRAINT sessionpath_session FOREIGN KEY (session) REFERENCES Session (id) DEFERRABLE,
 CONSTRAINT sessionpath_path FOREIGN KEY (path) REFERENCES Path (id) DEFERRABLE
);

CREATE INDEX IF NOT EXISTS sessionpath_session_type ON SessionPath (session, type);

CREATE UNIQUE INDEX IF NOT EXISTS sessionPath_session_type_path_unstopped
 ON SessionPath (session, type, path)
 WHERE stop IS NULL;

CREATE OR REPLACE FUNCTION SetSessionPath (
 inSession bigint,
 inType varchar,
 inPath bigint
) RETURNS bigint AS $$
DECLARE
 type_id integer;
BEGIN
 IF inSession IS NOT NULL
  AND inPath IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  -- Be sure to process any single session path one at a time without the need of a transaction or locking SessionPath table
  PERFORM pg_advisory_lock(inSession);
  BEGIN
  INSERT INTO SessionPath (session, type, path) (
   SELECT inSession, type_id, inPath
   FROM Dual
   LEFT JOIN SessionPath AS exists ON exists.session = inSession
    AND exists.path = inPath
    AND ((exists.type = type_id) OR (exists.type IS NULL AND type_id IS NULL))
    AND exists.stop IS NULL
   WHERE exists.session IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inSession);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inSession);
    RAISE;
  END;
 END IF;
 RETURN inSession;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopSessionPath (
 inSession bigint,
 inType varchar,
 inPath bigint
) RETURNS bigint AS $$
DECLARE
 type_id integer;
BEGIN
 IF inSession IS NOT NULL
  AND inPath IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  PERFORM pg_advisory_lock(inSession);
  BEGIN
  UPDATE SessionPath
  SET stop = NOW()
  WHERE session = inSession
   AND path = inPath
   AND stop IS NULL
   AND ((type = type_id) OR (type IS NULL AND type_id IS NULL));
  PERFORM pg_advisory_unlock(inSession);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inSession);
    RAISE;
  END;
 END IF;
 RETURN inSession;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW SessionURL AS
WITH latest AS (
 SELECT session, type, path, track, created,
  ROW_NUMBER() OVER (
   PARTITION BY session, type
   ORDER BY created DESC, path DESC
  ) AS rn
 FROM SessionPath
 WHERE stop IS NULL
)
SELECT latest.session, latest.type, Path.id AS path, Path.protocol, Path.host,
 Path.protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host ||
 CASE WHEN port IS NOT NULL THEN ':' || port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,latest.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND latest.track IS NOT  NULL) THEN '&' ELSE '' END ||  latest.track, '')
 END AS value,
 latest.created
FROM latest
JOIN Path ON Path.id = latest.path
WHERE latest.rn = 1;

-- ---------------------------------------------------------------------------
-- 0.2.11: ClaimSession (session id or token + email)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClaimSession (
 inSession bigint,
 inEmail varchar
) RETURNS bigint AS $$
DECLARE
 individual_id bigint;
 email_id integer;
 credential_id integer;
 last_agent integer;
 last_referring integer;
 last_ip inet;
 last_location integer;
 tok RECORD;
 sp RECORD;
 type_word varchar;
BEGIN
 IF inSession IS NULL OR inEmail IS NULL THEN
  RETURN NULL;
 END IF;

 individual_id := (SELECT GetIndividualEmail(inEmail));
 IF individual_id IS NULL THEN
  RETURN NULL;
 END IF;

 email_id := (SELECT GetEmail(inEmail));
 IF email_id IS NULL THEN
  RETURN individual_id;
 END IF;

 PERFORM pg_advisory_lock(individual_id);
 BEGIN
  SELECT id INTO credential_id
  FROM Credential
  WHERE individual = individual_id
   AND email = email_id
   AND revoked IS NULL
  LIMIT 1;
  IF credential_id IS NULL THEN
   INSERT INTO Credential (individual, email, culture) (
    SELECT individual_id, email_id, 1033
    FROM Dual
    LEFT JOIN Credential AS exists ON exists.individual = individual_id
     AND exists.email = email_id
     AND exists.revoked IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   SELECT id INTO credential_id
   FROM Credential
   WHERE individual = individual_id
    AND email = email_id
    AND revoked IS NULL
   LIMIT 1;
  END IF;
  PERFORM pg_advisory_unlock(individual_id);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(individual_id);
   RAISE;
 END;

 SELECT agentString, referring::integer, fromAddress, location
 INTO last_agent, last_referring, last_ip, last_location
 FROM SessionCredential
 WHERE session = inSession
 ORDER BY created DESC, id DESC
 LIMIT 1;

 FOR tok IN
  SELECT token, siteApplicationRelease
  FROM SessionToken
  WHERE session = inSession
 LOOP
  PERFORM SetSession(
   tok.token,
   tok.siteApplicationRelease,
   last_agent,
   credential_id,
   last_referring,
   last_ip,
   last_location
  );
 END LOOP;

 FOR sp IN
  SELECT type, path
  FROM SessionPath
  WHERE session = inSession
   AND stop IS NULL
   AND path IS NOT NULL
 LOOP
  IF sp.type IS NULL THEN
   type_word := NULL;
  ELSE
   type_word := (
    SELECT value FROM I18NWord WHERE id = sp.type LIMIT 1
   );
   IF type_word IS NULL THEN
    type_word := (
     SELECT value FROM Word WHERE id = sp.type LIMIT 1
    );
   END IF;
  END IF;
  PERFORM SetIndividualPath(individual_id, type_word, sp.path);
 END LOOP;

 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ClaimSession (
 inSessionToken varchar,
 inEmail varchar
) RETURNS bigint AS $$
DECLARE
 session_id bigint;
BEGIN
 IF inSessionToken IS NULL THEN
  RETURN NULL;
 END IF;
 SELECT session INTO session_id
 FROM SessionToken
 WHERE token = inSessionToken
 LIMIT 1;
 RETURN (SELECT ClaimSession(session_id, inEmail));
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 0.2.11: PathPassword, SetPathPassword / RevokePathPassword
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS PathPassword (
 path bigint NOT NULL,
 password integer NOT NULL,
 revoked timestamp,
 created timestamp NOT NULL DEFAULT NOW(),
 CONSTRAINT pathpassword_path FOREIGN KEY (path) REFERENCES Path (id) DEFERRABLE,
 CONSTRAINT pathpassword_password FOREIGN KEY (password) REFERENCES Password (id) DEFERRABLE
);

CREATE INDEX IF NOT EXISTS pathpassword_path ON PathPassword (path);

CREATE UNIQUE INDEX IF NOT EXISTS pathPassword_path_password_unrevoked
 ON PathPassword (path, password)
 WHERE revoked IS NULL;

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

-- Mark schema upgraded to 0.2.11 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.11 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '11');
