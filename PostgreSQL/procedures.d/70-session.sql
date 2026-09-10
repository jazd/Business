-- Web Session / Agent (diagram: web_session)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION RandomString (
 inLength integer
) RETURNS varchar AS $$
DECLARE
 base_chars varchar[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
 base integer := 62;
 x integer;
 result_string varchar;
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
DECLARE
 deviceName VARCHAR;
 deviceId integer;
 deviceVersionId integer;
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
DECLARE
 agentstring_id integer;
BEGIN
 IF inString IS NOT NULL THEN
  SELECT id INTO agentstring_id
  FROM AgentString
  WHERE userAgentString = inString
   AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
  LIMIT 1;
  IF agentstring_id IS NULL THEN
   -- Be sure to process any single agent string one at a time without the need of a transaction or locking AgentString table
   PERFORM pg_advisory_lock(inString);
   BEGIN
   INSERT INTO AgentString (agent,userAgentString) (
    SELECT inAgent, inString
    FROM Dual
    LEFT JOIN AgentString AS exists ON exists.userAgentString = inString
     AND ((exists.agent = inAgent) OR (exists.agent IS NULL AND inAgent IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inString);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inString);
     RAISE;
   END;
   SELECT id INTO agentstring_id
   FROM AgentString
   WHERE userAgentString = inString
    AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN agentstring_id;
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
DECLARE
 string_id INTEGER;
 deviceAgent_id INTEGER;
 deviceName VARCHAR;
 agentString_id INTEGER;
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
DECLARE
 existingSession bigint;
 referringURL integer;
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
 inStart timestamp,
 -- Type
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
BEGIN
 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, inCredential, inUAstring, inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild, inOSfamily, inOSmajor, inOSminor, inOSpatch, inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress, inLocation, inStart, NULL));
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
