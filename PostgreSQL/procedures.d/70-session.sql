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
 inStart timestamp
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
DECLARE
 newSession bigint;
 existingSession bigint;
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
   BEGIN
   INSERT INTO Session (lock) VALUES (0) RETURNING id INTO existingSession;
   INSERT INTO SessionToken (session,token,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created
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


