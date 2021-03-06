-- The MIT License (MIT) Copyright (c) 2014-2018 Stephen A Jazdzewski
-- NuoDB has functions and procedures
-- These links may help
-- http://doc.nuodb.com/Latest/Content/CREATE-FUNCTION.htm
-- http://doc.nuodb.com/Latest/Content/CREATE-PROCEDURE.htm
-- 
-- UDF_CACHE_SIZE defaults to 50, you may want to consider increasing this
USE Business;

-- Functions

DROP FUNCTION IF EXISTS GetWord;

SET DELIMITER @
CREATE FUNCTION GetWord (
 word_value STRING,
 culture_name STRING
) RETURNS INTEGER DETERMINISTIC AS
 IF (word_value IS NOT NULL)
  INSERT INTO Word (value, culture) (
   SELECT word_value, Culture.code
   FROM Culture
   LEFT JOIN Word AS does_exist ON does_exist.value = word_value
    AND does_exist.culture = Culture.code
   WHERE Culture.name = culture_name
    AND does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 
 RETURN (
  SELECT id
  FROM Word
  JOIN Culture ON Culture.name = culture_name
  WHERE Word.value = word_value
   AND Word.culture = Culture.code
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Default to en-US
SET DELIMITER @
CREATE FUNCTION GetWord (
 word_value STRING
) RETURNS INTEGER DETERMINISTIC AS
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
) RETURNS INTEGER DETERMINISTIC AS
 IF (ident_value IS NOT NULL)
  INSERT INTO Word (value, culture) (
   SELECT ident_value, NULL
   FROM Dual
   LEFT JOIN Word AS does_exist ON does_exist.value = ident_value
    AND does_exist.culture IS NULL
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Word
  WHERE Word.value = ident_value
   AND Word.culture IS NULL
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetSentence;

SET DELIMITER @
CREATE FUNCTION GetSentence (
 sentence_value STRING,
 culture_name STRING
) RETURNS INTEGER DETERMINISTIC AS
 IF (sentence_value IS NOT NULL)
  INSERT INTO Sentence (value, culture, length) (
   SELECT sentence_value, Culture.code, CHARACTER_LENGTH(sentence_value)
   FROM Culture
   LEFT JOIN Sentence AS does_exist ON does_exist.value = sentence_value
    AND does_exist.culture = Culture.code
   WHERE Culture.name = culture_name
    AND does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Sentence
  JOIN Culture ON Culture.name = culture_name
  WHERE Sentence.value = sentence_value
   AND Sentence.culture = Culture.code
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Default to en-US
SET DELIMITER @
CREATE FUNCTION GetSentence (
 sentence_value STRING
) RETURNS INTEGER DETERMINISTIC AS
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
) RETURNS INTEGER DETERMINISTIC AS
 IF (phrase_value IS NOT NULL)
  INSERT INTO Sentence (value, culture, length) (
   SELECT phrase_value, NULL, CHARACTER_LENGTH(phrase_value)
   FROM Dual
   LEFT JOIN Sentence AS does_exist ON does_exist.value = phrase_value
    AND does_exist.culture IS NULL
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Sentence
  WHERE Sentence.value = phrase_value
   AND Sentence.culture IS NULL
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetLocation;

SET DELIMITER @
CREATE FUNCTION GetLocation (
 lat FLOAT,
 long FLOAT,
 accuracy_code INTEGER
) RETURNS INTEGER AS
 VAR inLatitude NUMERIC(10,7) = lat;
 VAR inLongitude NUMERIC(11,7) = long;

 IF (inLatitude IS NOT NULL AND inLongitude IS NOT NULL)
  INSERT INTO Location (latitude, longitude, accuracy) (
   SELECT inLatitude, inLongitude, accuracy_code
   FROM Dual
   LEFT JOIN Location AS does_exist ON does_exist.latitude = inLatitude
    AND does_exist.longitude = inLongitude
    AND ((does_exist.accuracy = accuracy_code) OR (does_exist.accuracy IS NULL AND accuracy_code IS NULL))
   WHERE does_exist.id IS NULL
   LIMIT 1
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
  LIMIT 1
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
 VAR major_id INTEGER = GetWord(inMajor);
 VAR minor_id INTEGER;
 VAR patch_id INTEGER;
 VAR no_match INTEGER = -1;

 IF (major_id IS NOT NULL)
  minor_id = GetWord(inMinor);
  patch_id = GetWord(inPatch);
  INSERT INTO Version (major, minor, patch) (
   SELECT major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS does_exist ON does_exist.major = major_id
    AND ((does_exist.minor = COALESCE(minor_id, no_match)) OR (does_exist.minor IS NULL AND minor_id IS NULL))
    AND ((does_exist.patch = COALESCE(patch_id, no_match)) OR (does_exist.patch IS NULL AND patch_id IS NULL))
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE major = major_id
   AND ((minor = COALESCE(minor_id, no_match)) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = COALESCE(patch_id, no_match)) OR (patch IS NULL AND patch_id IS NULL))
   AND name IS NULL
  LIMIT 1
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
 VAR no_match INTEGER = -1;
 IF (inName IS NOT NULL)
  name_id = GetWord(inName);
  major_id = GetWord(inMajor);
  minor_id = GetWord(inMinor);
  patch_id = GetWord(inPatch);

  INSERT INTO Version (name, major, minor, patch) (
   SELECT name_id, major_id, minor_id, patch_id
   FROM Dual
   LEFT JOIN Version AS does_exist ON does_exist.name = name_id
    AND ((does_exist.major = COALESCE(major_id, no_match)) OR (does_exist.major IS NULL AND major_id IS NULL))
    AND ((does_exist.minor = COALESCE(minor_id, no_match)) OR (does_exist.minor IS NULL AND minor_id IS NULL))
    AND ((does_exist.patch = COALESCE(patch_id, no_match)) OR (does_exist.patch IS NULL AND patch_id IS NULL))
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Version
  WHERE name= name_id
   AND ((major = COALESCE(major_id, no_match)) OR (major IS NULL AND major_id IS NULL))
   AND ((minor = COALESCE(minor_id, no_match)) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = COALESCE(patch_id, no_match)) OR (patch IS NULL AND patch_id IS NULL))
  LIMIT 1
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
  build_id = GetWord(inBuild);
  INSERT INTO Release (build, version) (
   SELECT build_id AS build, inVersion AS version
   FROM Dual
   LEFT JOIN Release AS does_exist ON does_exist.version = inVersion
    AND ((does_exist.build = build_id) OR (does_exist.build IS NULL AND build_id IS NULL)) 
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Release
  WHERE version = inVersion
   AND ((build = build_id) OR (build IS NULL AND build_id IS NULL))
  LIMIT 1
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
  name_ident = GetWord(inName);
  INSERT INTO Application (name) (
   SELECT name_ident AS name
   FROM Dual
   LEFT JOIN Application AS does_exist ON does_exist.name = name_ident
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Application
  WHERE name = name_ident
  LIMIT 1
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
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM ApplicationRelease
  WHERE application = inApplication
   AND ((release = inRelease) OR (release IS NULL AND inRelease IS NULL))
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetPart/1;

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
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent IS NULL
   AND version IS NULL
   AND serial IS NULL
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetPartWithParent;

SET DELIMITER @
CREATE FUNCTION GetPartWithParent (
 inNameId INTEGER,
 inParentId INTEGER
) RETURNS INTEGER AS
 IF (inNameId IS NOT NULL AND inParentId IS NOT NULL)
  INSERT INTO Part (name, parent) (
   SELECT inNameId, inParentId
   FROM Dual
   LEFT JOIN Part AS does_exist ON does_exist.name = inNameId
    AND does_exist.parent = inParentId
    AND does_exist.version IS NULL
    AND does_exist.serial IS NULL
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = inNameId
   AND parent = inParentId
   AND version IS NULL
   AND serial IS NULL
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;


DROP FUNCTION IF EXISTS GetPart/2;

SET DELIMITER @
CREATE FUNCTION GetPart (
 inName STRING,
 inVersion INTEGER
) RETURNS INTEGER AS
 VAR name_id INTEGER;
 VAR sibling_parent INTEGER;
 VAR no_version_parent INTEGER;
 VAR parent_id INTEGER;

 IF (inName IS NOT NULL AND inVersion IS NOT NULL)
  name_id = GetSentence(inName);
  sibling_parent = (
   SELECT Part.parent
   FROM Part
   WHERE Part.name = name_id
    AND Part.version IS NOT NULL
    AND Part.serial IS NULL
   LIMIT 1
  );
  IF (sibling_parent IS NULL)
   no_version_parent = (
     SELECT Part.id
     FROM Part
     WHERE Part.name = name_id
      AND Part.parent IS NOT NULL
      AND Part.version IS NULL
      AND Part.serial IS NULL
     LIMIT 1
   );
   IF (no_version_parent IS NULL)
    parent_id = GetPart(inName);
   ELSE
    parent_id = no_version_parent;
   END_IF;

  ELSE
   parent_id = sibling_parent;
  END_IF;

  INSERT INTO Part (parent, name, version) (
   SELECT parent_id, name_id, inVersion
   FROM Dual
   LEFT JOIN Part AS does_exist ON does_exist.parent = parent_id
    AND does_exist.name = name_id
    AND does_exist.version = inVersion
    AND does_exist.serial IS NULL
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent = parent_id
   AND version = inVersion
   AND serial IS NULL
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;


DROP FUNCTION IF EXISTS GetPartbySerial;

SET DELIMITER @
CREATE FUNCTION GetPartbySerial (
 inParent INTEGER,
 inSerial STRING
) RETURNS INTEGER AS
 INSERT INTO Part (parent, name, version, serial) (
  SELECT inParent, parent.name, parent.version, inSerial
  FROM Part AS parent
  LEFT JOIN Part AS does_exist ON does_exist.parent = inParent
   AND does_exist.serial = inSerial
  WHERE parent.id = inParent
   AND does_exist.id IS NULL
   LIMIT 1
 );
 RETURN (
  SELECT part.id
  FROM Part
  WHERE Part.parent = inParent
   AND Part.serial = inSerial
  LIMIT 1
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
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM AssemblyApplicationRelease
  WHERE assembly = inAssembly
   AND applicationRelease = inApplicationRelease
   AND ((parent = inParent) OR (parent IS NULL AND inParent IS NULL))
  LIMIT 1
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
   LIMIT 1
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
  LIMIT 1
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
  INSERT INTO AgentString (agent,userAgentString) (
   SELECT inAgent, inString
   FROM Dual
   LEFT JOIN AgentString AS does_exist ON does_exist.userAgentString = inString
    AND ((does_exist.agent = inAgent) OR (does_exist.agent IS NULL AND inAgent IS NULL))
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM AgentString
  WHERE userAgentString = inString
   AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
  LIMIT 1
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
 VAR existingSession BIGINT;
 VAR referringURL INTEGER;

 referringURL = (GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet));

 existingSession = (
  SELECT session
  FROM SessionCredential
  WHERE credential IS NULL
  AND agentString = inAgentString
  AND fromAddress = inIPAddress
  AND ((referring = referringURL) OR (referring IS NULL AND referringURL IS NULL))
 );

 IF (existingSession IS NULL)
  INSERT INTO Session ("lock") VALUES (0);
  existingSession = LAST_INSERT_ID();
  INSERT INTO SessionCredential (session,agentString,fromAddress,referring)
  SELECT existingSession AS session, inAgentString AS agentString,
   inIPAddress AS fromAddress, referringURL
  FROM Dual;
 ELSE
  UPDATE Session SET touched = NOW() WHERE id = existingSession;
 END_IF;

 RETURN existingSession;
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
   LIMIT 1
  );

  IF (existingSession IS NULL)
   INSERT INTO Session ("lock") VALUES (0);
   existingSession = LAST_INSERT_ID();
   INSERT INTO SessionToken (session,token,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created FROM Dual
   );
  ELSE
   UPDATE Session SET touched = NOW() WHERE id = existingSession;
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

DROP FUNCTION IF EXISTS GetPostal;

SET DELIMITER @
CREATE FUNCTION GetPostal (
 countrycode STRING,
 zipcode STRING,
 city STRING,
 statecode STRING,
 state STRING,
 county STRING,
 lat FLOAT,
 long FLOAT,
 accuracy INTEGER
) RETURNS INTEGER AS
 VAR countrycode_id = (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(countrycode));
 VAR city_id = GetWord(city);
 VAR statecode_id = GetWord(statecode);
 VAR state_id = GetWord(state);
 VAR county_id = GetWord(county);
 VAR location_id = GetLocation(lat,long,accuracy);

 INSERT INTO Postal (country, code, state, stateabbreviation, county, city, location) (
  SELECT countrycode_id, zipcode, state_id, statecode_id, county_id, city_id, location_id
  FROM Dual
  LEFT JOIN Postal AS does_exist ON does_exist.country = countrycode_id
   AND UPPER(does_exist.code) = UPPER(zipcode)
  WHERE does_exist.id IS NULL
  LIMIT 1
 );

 RETURN (
  SELECT id
  FROM Postal
  WHERE country = countrycode_id
   AND UPPER(Postal.code) = UPPER(zipcode)
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetPostal (
 countrycode STRING,
 zipcode STRING
) RETURNS INTEGER AS
 RETURN (
  SELECT Postal.id
  FROM Postal
  JOIN Country ON UPPER(Country.code) = UPPER(countrycode)
  WHERE Postal.country = Country.id
   AND UPPER(Postal.code) = UPPER(zipcode)
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetPostal (
 zipcode STRING
) RETURNS INTEGER AS
 RETURN (
  SELECT Postal.id
  FROM Postal
  JOIN Country ON UPPER(Country.code) = 'USA'
  WHERE Postal.country = Country.id
   AND UPPER(Postal.code) = UPPER(zipcode)
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetAddress (
 street STRING,
 zipcode STRING,
 inPostalplus VARCHAR(4),
 lat FLOAT,
 long FLOAT,
 inAccuracy INTEGER
) RETURNS INTEGER AS
 VAR location_id = GetLocation(lat,long,inAccuracy);
 VAR zipcode_id = GetPostal(zipcode);

 IF (zipcode_id IS NOT NULL)
  IF (location_id IS NOT NULL)
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
  END_IF;

  INSERT INTO Address (line1, postal, postalplus, location) (
   SELECT street, zipcode_id, inPostalplus, location_id
   FROM Dual
   LEFT JOIN Address AS does_exist ON does_exist.postal = zipcode_id
    AND ((does_exist.postalplus = inPostalplus) OR (does_exist.postalplus IS NULL AND inPostalplus IS NULL))
    AND ((does_exist.location = location_id) OR (does_exist.location IS NULL AND location_id IS NULL))
    AND UPPER(does_exist.line1) = UPPER(street)
    AND does_exist.line2 IS NULL
    AND does_exist.line3 IS NULL
    AND does_exist.line4 IS NULL
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
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
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION GetAddress (
 street STRING,
 zipcode STRING,
 inPostalplus VARCHAR(4)
) RETURNS INTEGER AS
 VAR zipcode_id = GetPostal(zipcode);

 IF (zipcode_id IS NOT NULL)
  INSERT INTO Address (line1, postal, postalplus) (
   SELECT street, zipcode_id, inPostalplus
   FROM Dual
   LEFT JOIN Address AS does_exist ON does_exist.postal = zipcode_id
    AND ((does_exist.postalplus = inPostalplus) OR (does_exist.postalplus IS NULL AND inPostalplus IS NULL))
    AND UPPER(does_exist.line1) = UPPER(street)
    AND does_exist.line2 IS NULL
    AND does_exist.line3 IS NULL
    AND does_exist.line4 IS NULL
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Address
  WHERE postal = zipcode_id
   AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
   AND UPPER(line1) = UPPER(street)
   AND line2 IS NULL
   AND line3 IS NULL
   AND line4 IS NULL
   ORDER BY location LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;


DROP FUNCTION IF EXISTS GetGiven;

SET DELIMITER @
CREATE FUNCTION GetGiven (
 inGiven STRING
) RETURNS INTEGER AS
 IF (inGiven IS NOT NULL)
  INSERT INTO Given (value) (
   SELECT inGiven
   FROM DUAL
   LEFT JOIN Given AS does_exist ON does_exist.value = inGiven
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Given
  WHERE Given.value = inGiven
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetFamily;

SET DELIMITER @
CREATE FUNCTION GetFamily (
 inFamily STRING
) RETURNS INTEGER AS
 IF (inFamily IS NOT NULL)
  INSERT INTO Family (value) (
   SELECT inFamily
   FROM DUAL
   LEFT JOIN Family AS does_exist ON does_exist.value = inFamily
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Family
  WHERE Family.value = inFamily
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetName;

SET DELIMITER @
CREATE FUNCTION GetName (
 inFirst STRING,
 inMiddle STRING,
 inLast STRING
) RETURNS INTEGER AS
 VAR first_id INTEGER;
 VAR middle_id INTEGER;
 VAR last_id INTEGER;

 IF (inFirst IS NOT NULL OR inMiddle IS NOT NULL OR inLast IS NOT NULL)
  first_id = GetGiven(inFirst);
  middle_id = GetGiven(inMiddle);
  last_id = GetFamily(inLast);

  INSERT INTO Name (given, middle, family) (
   SELECT first_id, middle_id, last_id
   FROM DUAL
   LEFT JOIN Name AS does_exist ON
        ((does_exist.given = first_id) OR (does_exist.given IS NULL AND first_id IS NULL))
    AND ((does_exist.middle = middle_id) OR (does_exist.middle IS NULL AND middle_id IS NULL))
    AND ((does_exist.family = last_id) OR (does_exist.family IS NULL AND last_id IS NULL))
   WHERE does_exist.id IS NULL
   LIMIT 1
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Name
  WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
    AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
    AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;


DROP FUNCTION IF EXISTS GetIndividualPerson/6;

-- inBirth can't be NULL
SET DELIMITER @
CREATE FUNCTION GetIndividualPerson (
 inFirst STRING,
 inMiddle STRING,
 inLast STRING,
 inBirth date,
 inGoesBy STRING,
 inDeath date
) RETURNS BIGINT AS
 VAR name_id INTEGER;
 VAR goesBy_id INTEGER;
 VAR does_exist_id BIGINT;
 VAR return_id BIGINT;

 does_exist_id = (
   SELECT does_exist.id
   FROM DUAL
   LEFT JOIN Given ON Given.value = inFirst
   LEFT JOIN Family ON Family.value = inLast
   LEFT JOIN Name ON ((Name.given = Given.id) OR (Name.given IS NULL AND Given.id IS NULL))
    AND ((Name.family = Family.id) OR (Name.family IS NULL AND Family.id IS NULL))
   LEFT JOIN Individual AS does_exist ON does_exist.name IN (name_id, Name.id)
    AND ((CAST(does_exist.birth AS DATE) = inBirth) OR (inBirth IS NULL))
   LIMIT 1
 );

 IF (does_exist_id IS NULL)
  name_id = GetName(inFirst,inMiddle,inLast);
  goesBy_id = GetGiven(inGoesBy);

  IF (name_id IS NOT NULL)
   INSERT INTO Individual(name, goesBy, birth, death) VALUES (name_id, goesBy_id, inBirth, inDeath);
  END_IF;

  return_id = (
   SELECT id
   FROM Individual
   WHERE Individual.name = name_id
   AND (CAST(Individual.birth AS DATE) = inBirth)
   AND ((Individual.goesBy = goesBy_id) OR (goesBy_id IS NULL))
   AND ((CAST(Individual.death AS DATE) = inDeath) OR (Individual.death IS NULL AND inDeath IS NULL))
   LIMIT 1
  );
 ELSE
  return_id = does_exist_id;
 END_IF;

 RETURN return_id;
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetEntityName;

SET DELIMITER @
CREATE FUNCTION GetEntityName (
 inName STRING
) RETURNS INTEGER AS
 IF (inName IS NOT NULL)
  INSERT INTO Entity (name)
  SELECT inName
  FROM DUAL
  LEFT JOIN Entity AS does_exist ON UPPER(does_exist.name) = UPPER(inName)
  WHERE does_exist.id IS NULL
  LIMIT 1
  ;
 END_IF;

 RETURN (
  SELECT id
  FROM Entity
  WHERE UPPER(Entity.name) = UPPER(inName)
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetIndividualEntity/4;
SET DELIMITER @
CREATE FUNCTION GetIndividualEntity (
 inName STRING,
 inFormed date,
 inGoesBy STRING,
 inDissolved date
) RETURNS BIGINT AS
 VAR entity_name_id INTEGER;
 VAR goesBy_id INTEGER;

 entity_name_id = GetEntityName(inName);
 IF (entity_name_id IS NOT NULL)
  goesBy_id = GetGiven(inGoesBy);

  INSERT INTO Individual (entity, goesBy, birth, death)
  SELECT entity_name_id, goesBy_id, inFormed, inDissolved
  FROM DUAL
  LEFT JOIN Individual AS does_exist ON does_exist.entity = entity_name_id
  WHERE does_exist.id IS NULL
  LIMIT 1
  ;
 END_IF;

 RETURN (
  SELECT id FROM Individual
  WHERE Individual.entity = entity_name_id
  LIMIT 1
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetEmail/3;
SET DELIMITER @
CREATE OR REPLACE FUNCTION GetEmail (
 inUserName STRING,
 inPlus STRING,
 inHost STRING
) RETURNS INTEGER AS
IF (inUserName IS NOT NULL AND inHost IS NOT NULL)
 INSERT INTO Email (username, plus, host) (
  SELECT inUserName, inPlus, inHost
  FROM DUAL
  LEFT JOIN Email AS does_exist ON UPPER(does_exist.username) = UPPER(inUserName)
   AND UPPER(does_exist.host) = UPPER(inHost)
   AND ((UPPER(does_exist.plus) = UPPER(inPlus)) OR (does_exist.plus IS NULL AND inPlus IS NULL))
  WHERE does_exist.id IS NULL
  LIMIT 1
 );
END_IF;
RETURN (
 SELECT id
 FROM Email
 WHERE UPPER(username) = UPPER(inUserName)
  AND UPPER(host) = UPPER(inHost)
  AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
 LIMIT 1
);

END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetEmail/1;
SET DELIMITER @
CREATE OR REPLACE FUNCTION GetEmail (
 inEmail STRING
) RETURNS INTEGER AS

VAR plus_part STRING;
VAR user_part STRING = (SELECT SUBSTRING_INDEX(inEmail, '@', 1) FROM DUAL);
VAR host_part STRING = (SELECT SUBSTRING_INDEX(inEmail, '@', -1) FROM DUAL);
VAR plus_idx INTEGER = (SELECT LOCATE('+', user_part) FROM DUAL);

IF (plus_idx > 0)
 plus_part = (SELECT SUBSTR(user_part, plus_idx + 1) FROM DUAL);
 IF (plus_part = '')
  plus_part = NULL;
 END_IF;
 user_part = (SELECT SUBSTR(user_part, 1, plus_idx - 1) FROM DUAL);
END_IF;

RETURN GetEmail(user_part, plus_part, host_part);

END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS GetListIndividualName;
SET DELIMITER @
CREATE OR REPLACE FUNCTION GetListIndividualName (
 inListName STRING,
 inSetName STRING
) RETURNS INTEGER AS
VAR listName_id INTEGER;
VAR setName_id INTEGER;
VAR listIndividual_id INTEGER;

IF (inListName IS NOT NULL)
 -- Get names
 listName_id = GetWord(inListName);
 setName_id = GetWord(inSetName);

 -- Insert list name if it does not exist
 INSERT INTO ListIndividualName (name, listSet, optinStyle)
 SELECT listName_id, setName_id, 1
 FROM DUAL
 LEFT JOIN ListIndividualName AS does_exist ON does_exist.name = listName_id
  AND ((does_exist.listSet = setName_id) OR (does_exist.listSet IS NULL AND setName_id IS NULL))
  AND does_exist.optinStyle = 1
 WHERE does_exist.listIndividual IS NULL
 LIMIT 1
 ;
END_IF;

-- Get individual list
RETURN (
 SELECT listIndividual
 FROM ListIndividualName
 WHERE name = listName_id
  AND ((listSet = setName_id) OR (listSet IS NULL AND setName_id IS NULL))
  AND optinStyle = 1
 LIMIT 1
);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS ListSubscribe/4;
SET DELIMITER @
CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName STRING,
 inSetName STRING,
 inIndividual BIGINT,
 inSend STRING
) RETURNS INTEGER AS
VAR listIndividual_id INTEGER;
VAR sendField_id INTEGER;

IF (inIndividual IS NOT NULL AND inListName IS NOT NULL)
 sendField_id = GetIdentifier(LOWER(inSend));
 listIndividual_id = GetListIndividualName(inListName, inSetName);

 -- Insert individual into list
 INSERT INTO ListIndividual (id, individual, type)
 SELECT listIndividual_id AS id, inIndividual AS individual, sendField_id AS type
 FROM DUAL
 LEFT JOIN ListIndividual AS does_exist ON does_exist.id = listIndividual_id
  AND does_exist.individual = inIndividual
  AND does_exist.unlist IS NULL
 WHERE does_exist.id IS NULL
 LIMIT 1
 ;
END_IF;

RETURN listIndividual_id;
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS ListSubscribe/3;
SET DELIMITER @
CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName STRING,
 inSetName STRING,
 inIndividual BIGINT
) RETURNS INTEGER AS
-- Use default send to
RETURN ListSubscribe(inListName, inSetName, inIndividual, NULL);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS ListUnSubscribe/3;
SET DELIMITER @
CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName STRING,
 inSetName STRING,
 inIndividual BIGINT
) RETURNS INTEGER AS
VAR listIndividual_id INTEGER;

IF (inIndividual IS NOT NULL AND inListName IS NOT NULL)
 listIndividual_id = GetListIndividualName(inListName, inSetName);

 IF (listIndividual_id IS NOT NULL)
  UPDATE ListIndividual SET unlist = NOW()
  WHERE ListIndividual.id = listIndividual_id
   AND ListIndividual.individual = inIndividual
   AND ListIndividual.unlist IS NULL
 ;
 END_IF;
END_IF;

RETURN listIndividual_id;
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS ListUnSubscribe/2;
SET DELIMITER @
CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName STRING,
 inIndividual BIGINT
) RETURNS BIGINT AS
RETURN ListUnSubscribe(inListName, NULL, inIndividual);
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS SetIndividualEmail/3;
SET DELIMITER @
CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id BIGINT,
 inEmail_id INTEGER,
 inType STRING
) RETURNS BIGINT AS
VAR type_id INTEGER;

IF (inIndividual_id IS NOT NULL AND inEmail_id IS NOT NULL)
 type_id = GetWord(inType);
 INSERT INTO IndividualEmail (individual, email, type)
 SELECT inIndividual_id, inEmail_id, type_id
 FROM DUAL
 LEFT JOIN IndividualEmail AS does_exist ON does_exist.individual = inIndividual_id
  AND does_exist.email = inEmail_id
  AND ((does_exist.type = type_id) OR (does_exist.type IS NULL AND type_id IS NULL))
  AND does_exist.stop IS NULL
 WHERE does_exist.individual IS NULL
 LIMIT 1
 ;
END_IF;
RETURN inIndividual_id;
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS SetIndividualEmail/2;
SET DELIMITER @
CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id BIGINT,
 inEmail_id INTEGER
) RETURNS BIGINT AS
RETURN SetIndividualEmail(inIndividual_id, inEmail_id, NULL);
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
 RETURN LAST_INSERT_ID();
END_FUNCTION;
@
SET DELIMITER ;


-- DAG https://www.codeproject.com/Articles/22824/A-Model-to-Represent-Directed-Acyclic-Graphs-DAG-o
SET DELIMITER @
CREATE OR REPLACE FUNCTION AddEdge (
 v_start INTEGER,
 v_stop INTEGER
) RETURNS INTEGER AS
VAR v_id INTEGER;

-- can t start and stop at the same place
IF (v_start = v_stop)
 THROW (SELECT 'Start != Stop' FROM DUAL);
 RETURN NULL;
END_IF;

-- detect duplicate
VAR f INTEGER = (
 SELECT id
 FROM Edge
 WHERE start = v_start
 AND stop = v_stop
 AND hops = 0
);
IF (f IS NOT NULL)
 THROW (SELECT 'Duplicate, ' || v_start || ',' || v_stop || ' already exists' FROM DUAL);
 RETURN NULL; -- found duplicate
END_IF;

-- detect circular relation attempt
f = (
 SELECT id
 FROM Edge
 WHERE start = v_stop
 AND stop = v_start
);
IF (f IS NOT NULL)
 THROW (SELECT 'Circular relation rejected' FROM DUAL);
 RETURN NULL; -- found circular conflict
END_IF;

-- insert 0 hop edge
VAR nextid INTEGER = (SELECT NEXT VALUE FOR EDGE$IDENTITY_SEQUENCE FROM DUAL);
INSERT INTO edge (
 id,
 start, stop,
 entry, direct, exit)
VALUES (
 nextid,
 v_start,
 v_stop,
 nextid,
 nextid,
 nextid
);

v_id = nextid;

-- Connect graphs A (start) and B (stop) together
-- Step 1: A s incoming edges to B
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

-- Step 2: A to B s outgoing edges
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

-- Step 3: A s incoming edges to the stop node of B s outgoing edges
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
FROM edge A, edge B
WHERE A.stop = v_start
AND B.start = v_stop;

RETURN v_id;
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE PROCEDURE CreateRemoveEdgePurgeList AS
DROP TABLE IF EXISTS removeEdgePurgeList;
CREATE TEMPORARY TABLE removeEdgePurgeList (id int);
END_PROCEDURE;
@
SET DELIMITER ;


EXECUTE CreateRemoveEdgePurgeList;


SET DELIMITER @
CREATE OR REPLACE FUNCTION RemoveEdge (
 v_start INTEGER,
 v_stop INTEGER
) RETURNS INTEGER AS
VAR v_id INTEGER;
VAR v_count INTEGER;
-- detect if it actually exists
v_id = (
 SELECT id
 FROM edge
 WHERE start = v_start
 AND stop = v_stop
 AND hops = 0
);
IF (v_id IS NOT NULL)
 -- continue processing
ELSE
 THROW (SELECT 'Relation ' || v_start || ',' || v_stop || ' does not exists' FROM DUAL);
 RETURN NULL;
END_IF;

EXECUTE CreateRemoveEdgePurgeList;

-- Step 1: rows that were originally inserted for this direct edge
INSERT INTO removeEdgePurgeList
 SELECT id
 FROM edge
 WHERE direct = v_id;

-- Step 2: scan and find all dependent rows that are inserted after first
FOR
 INSERT INTO removeEdgePurgeList
 SELECT id FROM edge
 WHERE hops > 0
 AND (entry IN (SELECT id FROM removeEdgePurgeList)
  OR exit IN (SELECT id FROM removeEdgePurgeList))
 AND id NOT IN (SELECT id FROM removeEdgePurgeList);
END_FOR;

-- count the records to be deleted and then delete them
v_count = (
 SELECT count(id) FROM removeEdgePurgeList
);
DELETE FROM edge
WHERE id IN (SELECT id FROM removeEdgePurgeList);

RETURN v_count;
END_FUNCTION;
@
SET DELIMITER ;


-- Can Return NULL
SET DELIMITER @
CREATE OR REPLACE FUNCTION GetVertex (
 inVertexName STRING
) RETURNS INTEGER DETERMINISTIC AS
RETURN (
 SELECT vertex
 FROM VertexName
 WHERE VertexName.name = GetSentence(inVertexName)
 LIMIT 1
);
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE FUNCTION AddEdgeName (
 inStart STRING,
 inStop  STRING
) RETURNS INTEGER AS
VAR v_start INTEGER;
VAR v_stop  INTEGER;

v_start = GetVertex(inStart);
IF (v_start IS NULL)
 INSERT INTO VertexName (name) VALUES (GetSentence(inStart));
 v_start = (SELECT LAST_INSERT_ID() FROM DUAL);
END_IF;

v_stop = GetVertex(inStop);
IF (v_stop IS NULL)
 INSERT INTO VertexName (name) VALUES (GetSentence(inStop));
 v_stop = (SELECT LAST_INSERT_ID() FROM DUAL);
END_IF;

RETURN AddEdge(v_start, v_stop);
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE FUNCTION RemoveEdgeName (
 inStart STRING,
 inStop  STRING
) RETURNS INTEGER AS
VAR v_start INTEGER;
VAR v_stop  INTEGER;
VAR v_count INTEGER;

v_start = GetVertex(inStart);
v_stop  = GetVertex(inStop);

IF (v_start IS NOT NULL AND v_stop IS NOT NULL)
 v_count = (SELECT RemoveEdge(v_start, v_stop) FROM DUAL);
END_IF;

RETURN v_count;
END_FUNCTION;
@
SET DELIMITER ;


-- Can return NULL
SET DELIMITER @
CREATE OR REPLACE FUNCTION GetIndividualVertex (
 inIndividual BIGINT,
 inVertex  INTEGER
) RETURNS INTEGER AS
RETURN (
 SELECT VertexName.vertex
 FROM IndividualVertex
 JOIN VertexName ON VertexName.vertex = inVertex
 JOIN Edge ON Edge.start = inVertex
 WHERE IndividualVertex.individual = inIndividual
 ORDER BY Edge.hops ASC
 LIMIT 1
);
END_FUNCTION;
@
SET DELIMITER ;


-- Can return NULL
SET DELIMITER @
CREATE OR REPLACE FUNCTION GetIndividualVertex (
 inIndividual BIGINT
) RETURNS INTEGER AS
RETURN (
 SELECT VertexName.vertex
 FROM IndividualVertex
 JOIN VertexName ON VertexName.vertex = IndividualVertex.vertex
 LEFT JOIN Edge ON Edge.start = IndividualVertex.vertex
 WHERE IndividualVertex.individual = inIndividual
 ORDER BY Edge.hops ASC
 LIMIT 1
);
END_FUNCTION;
@
SET DELIMITER ;


-- Vertex without a name
SET DELIMITER @
CREATE OR REPLACE FUNCTION CreateVertex (
) RETURNS INTEGER AS
INSERT INTO VertexName (name) VALUES (NULL);
RETURN LAST_INSERT_ID();
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE FUNCTION SetIndividualVertex (
 inIndividual BIGINT,
 inType STRING
) RETURNS INTEGER AS
VAR v_id INTEGER = GetIndividualVertex(inIndividual);
VAR t_id INTEGER;

IF (inType IS NOT NULL AND inType != '')
 t_id = GetIdentifier(inType);
END_IF;

-- Create no-name Vertex
IF (v_id IS NULL)
 v_id = CreateVertex();
 INSERT INTO IndividualVertex (individual, vertex, type) VALUES (inIndividual, v_id, t_id);
END_IF;

RETURN v_id;
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE FUNCTION SetIndividualVertex (
 inIndividual BIGINT
) RETURNS INTEGER AS
RETURN SetIndividualVertex(inIndividual, NULL);
END_FUNCTION;
@
SET DELIMITER ;


-- Double Entry Accounting functions
--
-- Book single amounts into double entry Journal
SET DELIMITER @
CREATE OR REPLACE FUNCTION Book (
 inBook STRING,
 inAmount FLOAT
) RETURNS INTEGER AS
VAR book_id = (
 SELECT book
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
);

INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL);
VAR entry_id = LAST_INSERT_ID();

INSERT INTO JournalEntry (journal, book, entry,  account, credit, amount)
SELECT journal,
 book,
 entry_id AS entry,
 increase AS account,
 NOT (increaseCredit) AS credit,
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

RETURN entry_id;
END_FUNCTION;
@
SET DELIMITER ;


-- Book and return new balances
SET DELIMITER @
CREATE OR REPLACE FUNCTION BookBalance (
 inBook STRING,
 inAmount FLOAT
) RETURNS TABLE BookBalance (
 book INTEGER,
 entry INTEGER,
 account INTEGER,
 nameId INTEGER,
 name STRING,
 rightside BOOLEAN,
 type INTEGER,
 typeName STRING,
 debit FLOAT,
 credit FLOAT
) AS
VAR book_id = (
 SELECT BookName.book
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
);

VAR entry_id = Book(inBook, inAmount);

RETURN (
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
);
END_FUNCTION;
@
SET DELIMITER ;


-- Inventory Movement
--


-- Procedures
