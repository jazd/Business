-- The MIT License (MIT) Copyright (c) 2014-2015 Stephen A Jazdzewski
-- NuoDB has functions and procedures
-- These links may help
-- http://doc.nuodb.com/display/doc/CREATE+FUNCTION
-- http://doc.nuodb.com/display/doc/CREATE+PROCEDURE
-- 
-- UDF_CACHE_SIZE defaults to 50, you may want to consider increasing this
USE Business;

-- Functions

DROP FUNCTION IF EXISTS GetWord;

SET DELIMITER @
CREATE FUNCTION GetWord (
 word_value STRING,
 culture_name STRING
) RETURNS INTEGER AS
 IF (word_value IS NOT NULL)
  INSERT INTO Word (value, culture) (
   SELECT word_value, Culture.code
   FROM Culture
   LEFT JOIN Word AS does_exist ON does_exist.value = word_value
    AND does_exist.culture = Culture.code
   WHERE Culture.name = culture_name
    AND does_exist.id IS NULL
  );
 END_IF;
 
 RETURN (
  SELECT id
  FROM Word
  JOIN Culture ON Culture.name = culture_name
  WHERE Word.value = word_value
   AND Word.culture = Culture.code
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Default to en-US
SET DELIMITER @
CREATE FUNCTION GetWord (
 word_value STRING
) RETURNS INTEGER AS
 RETURN (
  SELECT GetWord(word_value, 'en-US') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Identifiers are normally by convention en-US based names used in programming and protocols
DROP FUNCTION IF EXISTS GetIdentifier;

SET DELIMITER @
CREATE FUNCTION GetIdentifier (
 ident_value STRING
) RETURNS INTEGER AS
 IF (ident_value IS NOT NULL)
  INSERT INTO Word (value, culture) (
   SELECT ident_value, NULL
   FROM Dual
   LEFT JOIN Word AS does_exist ON does_exist.value = ident_value
    AND does_exist.culture IS NULL
   WHERE does_exist.id IS NULL
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Word
  WHERE Word.value = ident_value
   AND Word.culture IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetSentence;

SET DELIMITER @
CREATE FUNCTION GetSentence (
 sentence_value STRING,
 culture_name STRING
) RETURNS INTEGER AS
 IF (sentence_value IS NOT NULL)
  INSERT INTO Sentence (value, culture, length) (
   SELECT sentence_value, Culture.code, CHARACTER_LENGTH(sentence_value)
   FROM Culture
   LEFT JOIN Sentence AS does_exist ON does_exist.value = sentence_value
    AND does_exist.culture = Culture.code
   WHERE Culture.name = culture_name
    AND does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Sentence
  JOIN Culture ON Culture.name = culture_name
  WHERE Sentence.value = sentence_value
   AND Sentence.culture = Culture.code
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Default to en-US
SET DELIMITER @
CREATE FUNCTION GetSentence (
 sentence_value STRING
) RETURNS INTEGER AS
 RETURN (
  SELECT GetSentence(sentence_value, 'en-US') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetIdentityPhrase;

SET DELIMITER @
CREATE FUNCTION GetIdentityPhrase (
 phrase_value STRING
) RETURNS INTEGER AS
 IF (phrase_value IS NOT NULL)
  INSERT INTO Sentence (value, culture, length) (
   SELECT phrase_value, NULL, CHARACTER_LENGTH(phrase_value)
   FROM Dual
   LEFT JOIN Sentence AS does_exist ON does_exist.value = phrase_value
    AND does_exist.culture IS NULL
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Sentence
  WHERE Sentence.value = phrase_value
   AND Sentence.culture IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetLocation;

SET DELIMITER @
CREATE FUNCTION GetLocation (
 inLatitude FLOAT,
 inLongitude FLOAT,
 accuracy_code INTEGER
) RETURNS INTEGER AS
 IF (inLatitude IS NOT NULL AND inLongitude IS NOT NULL)
  INSERT INTO Location (latitude, longitude, accuracy) (
   SELECT inLatitude, inLongitude, accuracy
   FROM Dual
   LEFT JOIN Location AS does_exist ON does_exist.latitude = inLatitude
    AND does_exist.longitude = inLongitude
    AND ((does_exist.accuracy = accuracy_code) OR (does_exist.accuracy IS NULL AND accuracy_code IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Location
  WHERE parent IS NULL
   AND marquee IS NULL
   AND longitude = inLongitude
   AND latitude = inLatitude
   AND ((accuracy = accuracy_code) OR (accuracy IS NULL AND accuracy_code IS NULL))
   AND level = 1
   AND altitudeabovesealevel IS NULL
   AND area IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetVersion;

SET DELIMITER @
CREATE FUNCTION GetVersion (
 inMajor STRING,
 inMinor STRING,
 inPatch STRING
) RETURNS INTEGER AS
 VAR major_id INTEGER;
 VAR minor_id INTEGER;
 VAR patch_id INTEGER;
 VAR major_id INTEGER = GetWord(inMajor);

 IF (major_id IS NOT NULL)
  minor_id = GetWord(inMinor);
  patch_id = GetWord(inPatch);
  INSERT INTO Version (major, minor, patch) (
   SELECT major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS does_exist ON does_exist.major = major_id
    AND ((does_exist.minor = minor_id) OR (does_exist.minor IS NULL AND minor_id IS NULL))
    AND ((does_exist.patch = patch_id) OR (does_exist.patch IS NULL AND patch_id IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE major = major_id
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
   AND name IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetVersionName;

SET DELIMITER @
CREATE FUNCTION GetVersionName (
 inName STRING,
 inMajor STRING,
 inMinor STRING,
 inPatch STRING
) RETURNS INTEGER AS
 VAR name_id INTEGER;
 VAR major_id INTEGER;
 VAR minor_id INTEGER;
 VAR patch_id INTEGER;
 IF (inName IS NOT NULL)
  name_id = GetWord(inName);
  major_id = GetWord(inMajor);
  minor_id = GetWord(inMinor);
  patch_id = GetWord(inPatch);
  INSERT INTO Version (name, major, minor, patch) (
   SELECT name_id, major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS does_exist ON does_exist.name = name_id
    AND ((does_exist.major = major_id) OR (does_exist.major IS NULL AND major_id IS NULL))
    AND ((does_exist.minor = minor_id) OR (does_exist.minor IS NULL AND minor_id IS NULL))
    AND ((does_exist.patch = patch_id) OR (does_exist.patch IS NULL AND patch_id IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE name= name_id
   AND ((major = major_id) OR (major IS NULL AND major_id IS NULL))
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetVersionName (
 inName STRING
) RETURNS INTEGER AS
 RETURN GetVersionName(inName, NULL, NULL, NULL);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetRelease;

SET DELIMITER @
CREATE FUNCTION GetRelease (
 inVersion INTEGER,
 inBuild STRING
) RETURNS INTEGER AS
 VAR build_id INTEGER;
 IF (inVersion IS NOT NULL)
  build_id = GetIdentifier(inBuild);
  INSERT INTO Release (build, version) (
   SELECT build_id AS build, inVersion AS version
   FROM Dual
   LEFT JOIN Release AS does_exist ON does_exist.version = inVersion
    AND ((does_exist.build = build_id) OR (does_exist.build IS NULL AND build_id IS NULL)) 
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Release
  WHERE version = inVersion
   AND ((build = build_id) OR (build IS NULL AND build_id IS NULL))
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetRelease (
 inVersion INTEGER
) RETURNS INTEGER AS
 RETURN GetRelease(inVersion, NULL);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetApplication;

SET DELIMITER @
CREATE FUNCTION GetApplication(
 inName STRING
) RETURNS INTEGER AS
 VAR name_ident INTEGER;
 IF (inName IS NOT NULL)
  name_ident = GetIdentifier(inName);
  INSERT INTO Application (name) (
   SELECT name_ident AS name
   FROM Dual
   LEFT JOIN Application AS does_exist ON does_exist.name = name_ident
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Application
  WHERE name = name_ident
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetApplicationRelease;

SET DELIMITER @
CREATE FUNCTION GetApplicationRelease (
 inApplication INTEGER,
 inRelease INTEGER
) RETURNS INTEGER AS
 IF (inApplication IS NOT NULL)
  INSERT INTO ApplicationRelease (application, release) (
   SELECT inApplication AS application, inRelease AS release
   FROM Dual
   LEFT JOIN ApplicationRelease AS does_exist ON does_exist.application = inApplication
    AND ((does_exist.release = inRelease) OR (does_exist.release IS NULL AND inRelease IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM ApplicationRelease
  WHERE application = inApplication
   AND ((release = inRelease) OR (release IS NULL AND inRelease IS NULL))
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetPart;

SET DELIMITER @
CREATE FUNCTION GetPart (
 inName STRING
) RETURNS INTEGER AS
 VAR name_id INTEGER;
 IF (inName IS NOT NULL)
  name_id = GetSentence(inName);
  INSERT INTO Part (name) (
   SELECT name_id
   FROM Dual
   LEFT JOIN Part AS does_exist ON does_exist.name = name_id
    AND does_exist.parent IS NULL
    AND does_exist.version IS NULL
    AND does_exist.serial IS NULL
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent IS NULL
   AND version IS NULL
   AND serial IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetAssemblyApplicationRelease;

SET DELIMITER @
CREATE FUNCTION GetAssemblyApplicationRelease (
 inAssembly INTEGER,
 inApplicationRelease INTEGER,
 inParent INTEGER
) RETURNS INTEGER AS
 IF (inAssembly IS NOT NULL AND inApplicationRelease IS NOT NULL)
  INSERT INTO AssemblyApplicationRelease (parent, assembly, applicationRelease) (
   SELECT inParent AS parent, inAssembly AS assembly, inApplicationRelease AS applicationRelease
   FROM Dual
   LEFT JOIN AssemblyApplicationRelease AS does_exist ON does_exist.assembly = inAssembly
    AND does_exist.applicationRelease = inApplicationRelease
    AND ((does_exist.parent = inParent) OR (does_exist.parent IS NULL AND inParent IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM AssemblyApplicationRelease
  WHERE assembly = inAssembly
   AND applicationRelease = inApplicationRelease
   AND ((parent = inParent) OR (parent IS NULL AND inParent IS NULL))
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetAssemblyApplicationRelease (
 inAssembly INTEGER,
 inApplicationRelease INTEGER
) RETURNS INTEGER AS
RETURN GetAssemblyApplicationRelease(inAssembly, inApplicationRelease, NULL);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetPath;

SET DELIMITER @
CREATE FUNCTION GetPath (
 inProtocol STRING,
 inSecure INTEGER,
 inHost STRING,
 inValue STRING,
 inGet STRING
) RETURNS INTEGER AS
 VAR is_secure INTEGER = 0;
 IF (inValue IS NOT NULL OR inHost IS NOT NULL)
  IF (inSecure IS NOT NULL AND inSecure != 0)
    is_secure = 1;
  END_IF;
  INSERT INTO Path (protocol, secure, host, value, get) (
   SELECT inProtocol, is_secure, inHost, inValue, inGet
   FROM Dual
   LEFT JOIN Path AS does_exist ON does_exist.protocol = inProtocol
    AND does_exist.secure = is_secure
    AND ((does_exist.host = inHost) OR (does_exist.host IS NULL AND inHost IS NULL))
    AND ((does_exist.value = inValue) OR (does_exist.value IS NULL OR inValue IS NULL))
    AND ((does_exist.get = inGet) OR (does_exist.get IS NULL AND inGet IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Path
  WHERE protocol = inProtocol
   AND secure = is_secure
   AND ((host = inHost) OR (host IS NULL and inHost IS NULL))
   AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
   AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetURL;

SET DELIMITER @
CREATE FUNCTION GetURL (
 inSecure INTEGER,
 inHost STRING,
 inValue STRING,
 inGet STRING
) RETURNS INTEGER AS
 RETURN GetPath('http', inSecure, inHost, inValue, inGet);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetFile;

SET DELIMITER @
CREATE FUNCTION GetFile (
 inHost STRING,
 inPathValue STRING,
 inFileGet STRING
) RETURNS INTEGER AS
 RETURN GetPath('file', 0, inHost, inPathValue, inFileGet);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetDeviceOSApplicationRelease;

-- Returns an AssemblyApplicationRelease id for device, os and application.  OS is the parent.
SET DELIMITER @
CREATE FUNCTION GetDeviceOSApplicationRelease (
 inUAfamily STRING,
 inUAmajor STRING,
 inUAminor STRING,
 inUApatch STRING,
 inUAbuild STRING,
 inOSfamily STRING,
 inOSmajor STRING,
 inOSminor STRING,
 inOSpatch STRING,
 inDeviceBrand STRING,
 inDeviceModel STRING,
 inDeviceFamily STRING
) RETURNS INTEGER AS
 VAR deviceName STRING = (SELECT COALESCE(inDeviceFamily, 'Unknown') FROM Dual);

 RETURN GetAssemblyApplicationRelease(
   GetPart(deviceName),
   GetApplicationRelease(
    GetApplication(inUAfamily),
    GetRelease(
     GetVersion(inUAmajor,inUAminor,inUApatch),
     inUAbuild)
   ),
   GetAssemblyApplicationRelease(
    GetPart(deviceName),
    GetApplicationRelease(
     GetApplication(inOSfamily),
     GetRelease(
      GetVersionName(inOSfamily, inOSmajor, inOSminor, inOSpatch)
     )
    )
   )
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetAgentString;

SET DELIMITER @
CREATE FUNCTION GetAgentString (
 inAgent INTEGER,
 inString INTEGER
) RETURNS INTEGER AS
 IF (inString IS NOT NULL)
  INSERT INTO AgentString (agent,"string") (
   SELECT inAgent, inString
   FROM Dual
   LEFT JOIN AgentString AS does_exist ON does_exist."string" = inString
    AND ((does_exist.agent = inAgent) OR (does_exist.agent IS NULL AND inAgent IS NULL))
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM AgentString
  WHERE "string" = inString
   AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS AnonymousSession;

-- SELECT AnonymousSession(1, 0,'www.ibm.com',NULL,NULL,'107.77.97.52') FROM Dual;
SET DELIMITER @
CREATE FUNCTION AnonymousSession (
 inAgentString INTEGER,
 inRefSecure INTEGER,
 inRefHost STRING,
 inRefPath STRING,
 inRefGet STRING,
 inIPAddress STRING
) RETURNS BIGINT AS
 VAR newSession BIGINT;

 INSERT INTO Session (lock) VALUES (0);
 newSession = (SELECT MAX(id) FROM Session);

 INSERT INTO SessionCredential (session,agentString,fromAddress,referring)
 SELECT newSession AS session, inAgentString AS agentString,
  inIPAddress AS fromAddress, 
  GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet)
 FROM Dual
 ;

 RETURN newSession;
END_FUNCTION;
@
SET DELIMITER ;

-- Consider https://github.com/ua-parser to parse the user agent string
-- SELECT AnonymousSession('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36','Chrome','43','0','2357','130','Linux',NULL,NULL,NULL,NULL,NULL,'Other',0,'www.ibm.com',NULL,NULL,'107.77.97.52') FROM Dual;

SET DELIMITER @
CREATE FUNCTION AnonymousSession (
 inUAstring STRING,
 inUAfamily STRING,
 inUAmajor STRING,
 inUAminor STRING,
 inUApatch STRING,
 inUAbuild STRING,
 inOSfamily STRING,
 inOSmajor STRING,
 inOSminor STRING,
 inOSpatch STRING,
 inDeviceBrand STRING,
 inDeviceModel STRING,
 inDeviceFamily STRING,
 inRefSecure INTEGER,
 inRefHost STRING,
 inRefPath STRING,
 inRefGet STRING,
 inIPAddress STRING
) RETURNS BIGINT AS
 VAR deviceAgent_id INTEGER;
 VAR deviceName STRING;
 VAR agentString_id INTEGER;
 VAR string_id STRING = GetIdentityPhrase(inUAstring);

 deviceAgent_id = GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily);

 agentString_id = GetAgentString(deviceAgent_id, string_id);

 RETURN AnonymousSession(agentString_id, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS SetSession;

SET DELIMITER @
CREATE FUNCTION SetSession (
 inSessionToken STRING,
 inSiteApplicationRelease INTEGER,
 inAgentString INTEGER,
 inCredential INTEGER,
 inReferring INTEGER,
 inIPAddress STRING,
 inLocation INTEGER,
 inStart timestamp
) RETURNS BIGINT AS
 VAR existingSession BIGINT;
 IF (inSessionToken IS NOT NULL)
  existingSession = (
   SELECT session
   FROM SessionToken
   WHERE token = inSessionToken
    AND (
     (siteApplicationRelease = inSiteApplicationRelease)
      OR (siteApplicationRelease IS NULL AND inSiteApplicationRelease IS NULL)
    )
  );

  IF (existingSession IS NULL)
   INSERT INTO Session (lock) VALUES (0);
   existingSession = (SELECT MAX(id) FROM Session);
   INSERT INTO SessionToken (session,token,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created FROM Dual
   );
  END_IF;

  INSERT INTO SessionCredential (session, agentString, credential, referring, fromAddress, location) (
   SELECT existingSession, inAgentString, inCredential, inReferring, inIPAddress, inLocation
   FROM Dual
   LEFT JOIN SessionCredential AS does_exist ON does_exist.session = existingSession
    AND ((agentString = inAgentString) OR (agentString IS NULL AND inAgentString IS NULL))
    AND ((credential = inCredential) OR (credential IS NULL AND inCredential IS NULL))
    AND ((referring = inReferring) OR (referring IS NULL AND inReferring IS NULL))
    AND ((fromAddress = inIPAddress) OR (fromAddress IS NULL AND inIPAddress IS NULL))
    AND ((location = inLocation) OR (location IS NULL AND inLocation IS NULL))
   WHERE does_exist.id IS NULL
  );

 END_IF;
 RETURN existingSession;
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION SetSession (
 inSessionToken STRING,
 inSiteApplicationRelease INTEGER,
 inAgentString INTEGER,
 inCredential INTEGER,
 inReferring INTEGER,
 inIPAddress STRING,
 inLocation INTEGER
) RETURNS BIGINT AS
 RETURN SetSession(inSessionToken, inSiteApplicationRelease, inAgentString, inCredential, inReferring, inIPAddress, inLocation, NULL);
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION SetSession (
 inSessionToken STRING,
 inSiteApplicationRelease INTEGER,
 inCredential INTEGER,
 inUAstring STRING,
 inUAfamily STRING,
 inUAmajor STRING,
 inUAminor STRING,
 inUApatch STRING,
 inUAbuild STRING,
 inOSfamily STRING,
 inOSmajor STRING,
 inOSminor STRING,
 inOSpatch STRING,
 inDeviceBrand STRING,
 inDeviceModel STRING,
 inDeviceFamily STRING,
 inRefSecure INTEGER,
 inRefHost STRING,
 inRefPath STRING,
 inRefGet STRING,
 inIPAddress STRING,
 inLocation INTEGER,
 inStart timestamp
) RETURNS BIGINT AS
 VAR string_id INTEGER = GetIdentityPhrase(inUAstring);

 VAR deviceAgent_id INTEGER = GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily);

 VAR agentString_id INTEGER = GetAgentString(deviceAgent_id, string_id);

 VAR referring_id INTEGER = GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet);

 RETURN SetSession(inSessionToken, inSiteApplicationRelease, agentString_id, inCredential, referring_id, inIPAddress, inLocation, inStart);
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION SetSession (
 inSession STRING,
 inSiteApplicationRelease INTEGER,
 inCredential INTEGER,
 inUAstring STRING,
 inUAfamily STRING,
 inUAmajor STRING,
 inUAminor STRING,
 inUApatch STRING,
 inUAbuild STRING,
 inOSfamily STRING,
 inOSmajor STRING,
 inOSminor STRING,
 inOSpatch STRING,
 inDeviceBrand STRING,
 inDeviceModel STRING,
 inDeviceFamily STRING,
 inRefSecure INTEGER,
 inRefHost STRING,
 inRefPath STRING,
 inRefGet STRING,
 inIPAddress STRING,
 inLocation INTEGER
) RETURNS BIGINT AS
 RETURN SetSession(inSession,inSiteApplicationRelease,inCredential,inUAstring,inUAfamily,inUAmajor,inUAminor,inUApatch,inUAbuild,inOSfamily,inOSmajor,inOSminor,inOSpatch,inDeviceBrand,inDeviceModel,inDeviceFamily,inRefSecure,inRefHost,inRefPath,inRefGet,inIPAddress,inLocation,NULL);
END_FUNCTION;
@
SET DELIMITER ;


DROP FUNCTION IF EXISTS SetSchemaVersion;

SET DELIMITER @
CREATE FUNCTION SetSchemaVersion (
 inSchemaName STRING,
 inMajor STRING,
 inMinor STRING,
 inPatch STRING
) RETURNS INTEGER AS
 VAR schema_id INTEGER;
 VAR version_id INTEGER;
 IF (inSchemaName IS NOT NULL)
  schema_id = GetWord(inSchemaName);
  version_id = GetVersion(inMajor, inMinor, inPatch);
 END_IF;

 INSERT INTO SchemaVersion (schema, version) VALUES (schema_id, version_id);
 RETURN (SELECT MAX(build) FROM SchemaVersion);
END_FUNCTION;
@
SET DELIMITER ;


-- Procedures
