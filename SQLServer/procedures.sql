-- Identifiers are normally by convention en-US based names used in programming and protocols
-- Return the Id of an identifier
-- It is inserted if it does not already exist
IF OBJECT_ID('GetIdentifier', 'P') IS NOT NULL
 DROP PROCEDURE GetIdentifier;
GO
CREATE PROCEDURE GetIdentifier
 @IdentValue varchar(35)
AS
IF @IdentValue IS NOT NULL
BEGIN
 INSERT INTO Word (value, culture) (
  SELECT TOP 1 @IdentValue, NULL
  FROM Dual
  LEFT JOIN Word AS does_exists ON UPPER(does_exists.value) = @IdentValue
   AND does_exists.culture IS NULL
  WHERE does_exists.id IS NULL
 )
END
BEGIN
RETURN (
 SELECT TOP 1 id
 FROM Word
 WHERE Word.value = @IdentValue
   AND Word.culture IS NULL
)
END
GO

-- Default to culture = 1033 'en-US'
IF OBJECT_ID('GetWord', 'P') IS NOT NULL
 DROP PROCEDURE GetWord;
GO
CREATE PROCEDURE GetWord
 @WordValue varchar(35)
AS
IF @WordValue IS NOT NULL
BEGIN
 INSERT INTO Word (value, culture) (
  SELECT TOP 1 @WordValue, 1033
  FROM Dual
  LEFT JOIN Word AS does_exists ON UPPER(does_exists.value) = @WordValue
   AND does_exists.culture = 1033
  WHERE does_exists.id IS NULL
 )
END
BEGIN
RETURN (
 SELECT TOP 1 id
 FROM Word
 WHERE Word.value = @WordValue
   AND Word.culture = 1033
)
END
GO

IF OBJECT_ID('GetVersion', 'P') IS NOT NULL
 DROP PROCEDURE GetVersion;
GO
CREATE PROCEDURE GetVersion
 @inMajor varchar(35),
 @inMinor varchar(35) = NULL,
 @inPatch varchar(35) = NULL
AS
DECLARE @major_id integer;
DECLARE @minor_id integer;
DECLARE @patch_id integer;

IF @inMajor IS NOT NULL
BEGIN
 EXEC @major_id = GetWord @inMajor

 IF @inMinor IS NOT NULL
 BEGIN
  EXEC @minor_id = GetWord @inMinor
 END
 IF @inPatch IS NOT NULL
 BEGIN
  EXEC @patch_id = GetWord @inPatch
 END
 INSERT INTO Version (major, minor, patch) (
  SELECT TOP 1 @major_id, @minor_id, @patch_id
  FROM DUAL
  LEFT JOIN Version AS does_exist ON does_exist.major = @major_id
   AND ((does_exist.minor = @minor_id) OR (does_exist.minor IS NULL AND @minor_id IS NULL))
   AND ((does_exist.patch = @patch_id) OR (does_exist.patch IS NULL AND @patch_id IS NULL))
  WHERE does_exist.id IS NULL
 )
 RETURN (
  SELECT TOP 1 id
  FROM Version
  WHERE major = @major_id
   AND ((minor = @minor_id) OR (minor IS NULL AND @minor_id IS NULL))
   AND ((patch = @patch_id) OR (patch IS NULL AND @patch_id IS NULL))
   AND name IS NULL
 )
END
GO

IF OBJECT_ID('GetRelease', 'P') IS NOT NULL
 DROP PROCEDURE GetRelease;
GO
CREATE PROCEDURE GetRelease
 @inVersion integer,
 @inBuild varchar(35)
AS
DECLARE @build_id integer = NULL;

IF @inVersion IS NOT NULL
BEGIN
 IF @inBuild IS NOT NULL
 BEGIN
   EXEC @build_id = GetWord @inBuild
 END
 INSERT INTO Release (build, version) (
  SELECT TOP 1 @build_id AS build, @inVersion AS version
  FROM DUAL
  LEFT JOIN Release AS does_exists ON does_exists.version = @inVersion
   AND ((does_exists.build = @build_id) OR (does_exists.build IS NULL AND @build_id IS NULL))
  WHERE does_exists.id IS NULL
 )
END
RETURN (
 SELECT TOP 1 id
 FROM Release
 WHERE version = @inVersion
  AND ((build = @build_id) OR (build IS NULL AND @build_id IS NULL))
)
GO

IF OBJECT_ID('GetApplication', 'P') IS NOT NULL
 DROP PROCEDURE GetApplication;
GO
CREATE PROCEDURE GetApplication
 @inName varchar(35)
AS
DECLARE @name_id integer;
IF @inName IS NOT NULL
BEGIN
 EXEC @name_id = GetWord @inName
 INSERT INTO Application (name) (
  SELECT TOP 1 @name_id AS name
  FROM DUAL
  LEFT JOIN Application AS does_exists ON does_exists.name = @name_id
  WHERE does_exists.id IS NULL
 )
END

RETURN (
 SELECT TOP 1 id
 FROM Application
 WHERE name = @name_id
)
GO

IF OBJECT_ID('GetApplicationRelease', 'P') IS NOT NULL
 DROP PROCEDURE GetApplicationRelease;
GO
CREATE PROCEDURE GetApplicationRelease
 @inApplication integer,
 @inRelease integer
AS
IF @inApplication IS NOT NULL
BEGIN
 INSERT INTO ApplicationRelease (application, release) (
  SELECT TOP 1 @inApplication AS application, @inRelease AS release
  FROM DUAL
  LEFT JOIN ApplicationRelease AS does_exists ON does_exists.application = @inApplication
   AND ((does_exists.release = @inRelease) OR (does_exists.release IS NULL AND @inRelease IS NULL))
  WHERE does_exists.id IS NULL
 )
END
RETURN (
 SELECT TOP 1 id
 FROM ApplicationRelease
 WHERE application = @inApplication
  AND ((release = @inRelease) OR (release IS NULL AND @inRelease IS NULL))
)
GO


IF OBJECT_ID('GetPath', 'P') IS NOT NULL
 DROP PROCEDURE GetPath;
GO
CREATE PROCEDURE GetPath
 @inProtocol varchar(4),
 @inSecure smallint,
 @inHost varchar(64),
 @inValue varchar(256),
 @inGet varchar(256) = NULL
AS
DECLARE @is_secure integer = 0;
-- host and path can not both be null
IF @inValue IS NOT NULL OR @inHost IS NOT NULL
BEGIN
 -- Default to false or 0
 IF @inSecure IS NOT NULL AND @inSecure != 0
 BEGIN
   SET @is_secure = 1
 END
 INSERT INTO Path (protocol, secure, host, value, get) (
  SELECT TOP 1 @inProtocol, @is_secure, @inHost, @inValue, @inGet
  FROM DUAL
  LEFT JOIN Path AS does_exists ON does_exists.protocol = @inProtocol
   AND does_exists.secure = @is_secure
   AND ((does_exists.host = @inHost) OR (does_exists.host IS NULL AND @inHost IS NULL))
   AND ((does_exists.value = @inValue) OR (does_exists.value IS NULL OR @inValue IS NULL))
   AND ((does_exists.get = @inGet) OR (does_exists.get IS NULL AND @inGet IS NULL))
   WHERE does_exists.id IS NULL
 )
END
RETURN (
 SELECT TOP 1 id
 FROM Path
 WHERE protocol = @inProtocol
  AND secure = @is_secure
  AND ((host = @inHost) OR (host IS NULL and @inHost IS NULL))
  AND ((value = @inValue) OR (value IS NULL AND @inValue IS NULL))
  AND ((get = @inGet) OR (get IS NULL AND @inGet IS NULL))
)
GO


IF OBJECT_ID('GetURL', 'P') IS NOT NULL
 DROP PROCEDURE GetURL;
GO
CREATE PROCEDURE GetURL
 @inSecure smallint,
 @inHost varchar(64),
 @inValue varchar(256),
 @inGet varchar(256) = NULL
AS
DECLARE @pathId integer
BEGIN
 EXEC @pathId = GetPath 'http', @inSecure, @inHost, @inValue, @inGet
END
RETURN @pathId
GO

IF OBJECT_ID('GetFile', 'P') IS NOT NULL
 DROP PROCEDURE GetFile;
GO
CREATE PROCEDURE GetFile
 @inHost varchar(64),
 @inPathValue varchar(256),
 @inFileGet varchar(256) = NULL
AS
DECLARE @pathId integer
BEGIN
 EXEC @pathId = GetPath 'file', 0, @inHost, @inPathValue, @inFileGet
 END
RETURN @pathId
GO

IF OBJECT_ID('GetGiven', 'P') IS NOT NULL
 DROP PROCEDURE GetGiven;
GO
CREATE PROCEDURE GetGiven
 @inGiven varchar(25)
AS
IF @inGiven IS NOT NULL
BEGIN
 INSERT INTO Given (value) (
  SELECT TOP 1 @inGiven
  FROM DUAL
  LEFT JOIN Given AS does_exists ON does_exists.value = @inGiven
  WHERE does_exists.id IS NULL
 )
END
RETURN (
 SELECT TOP 1 id
 FROM Given
 WHERE Given.value = @inGiven
)
GO

IF OBJECT_ID('GetEntityName', 'P') IS NOT NULL
 DROP PROCEDURE GetEntityName;
GO
CREATE PROCEDURE GetEntityName
 @inName varchar(50)
AS
IF @inName IS NOT NULL
BEGIN
 INSERT INTO Entity (name)
 SELECT TOP 1 @inName
 FROM DUAL
 LEFT JOIN Entity AS does_exists ON does_exists.name = @inName
 WHERE does_exists.id IS NULL
END
RETURN (
 SELECT TOP 1 id
 FROM Entity
 WHERE Entity.name = @inName
)
GO

IF OBJECT_ID('GetIndividualEntity', 'P') IS NOT NULL
 DROP PROCEDURE GetIndividualEntity;
GO
CREATE PROCEDURE GetIndividualEntity
 @inName varchar(50),
 @inFormed date = NULL,
 @inGoesBy varchar(25) = NULL,
 @inDissolved date = NULL
AS
DECLARE @entity_name_id integer;
DECLARE @goesBy_id integer;
IF @inName IS NOT NULL
BEGIN
 EXEC @entity_name_id = GetEntityName @inName
END
IF @entity_name_id IS NOT NULL
 AND @inGoesBy IS NOT NULL
 -- GoesBy is required to insert new record
BEGIN
 EXEC @goesBy_id = GetGiven @inGoesBy
 INSERT INTO Individual (entity, goesBy, birth, death)
 SELECT TOP 1 @entity_name_id, @goesBy_id, @inFormed, @inDissolved
 FROM DUAL
 LEFT JOIN Individual AS does_exists ON does_exists.entity = @entity_name_id
 WHERE does_exists.id IS NULL
END
-- Lookup by Entity name then GoesBy
RETURN (
 SELECT TOP 1 id
 FROM (
  SELECT id
  FROM Individual
  WHERE Individual.entity = @entity_name_id
  UNION ALL
  SELECT Individual.id
  FROM Given
  JOIN Individual ON Individual.goesBy = Given.id
  WHERE Given.value = @inName
 ) AS Options
)
GO
