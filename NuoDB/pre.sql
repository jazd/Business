-- The MIT License (MIT) Copyright (c) 2017-2018 Stephen A Jazdzewski
-- NuoDB has functions and procedures
-- These links may help
-- http://doc.nuodb.com/Latest/Content/CREATE-FUNCTION.htm
-- http://doc.nuodb.com/Latest/Content/CREATE-PROCEDURE.htm
-- Functions used in views

-- First drop views
DROP VIEW PeopleEvent;
DROP VIEW IndividualPersonEvent;
DROP VIEW ParedAgentStrings;
DROP VIEW Entities;
DROP VIEW PeopleEvent;
DROP VIEW People;
DROP VIEW List;
DROP VIEW Sessions;
DROP VIEW EmailAddress;
DROP VIEW URL;
DROP VIEW Addresses;
DROP VIEW IndividualURL;
DROP VIEW IndividualEmailAddress;
DROP VIEW ParsedAgentString;
DROP VIEW ParsedAgentStringShort;
DROP VIEW Assemblies;
DROP VIEW AssemblyParts;
DROP VIEW Parts CASCADE;
DROP VIEW VersionNames;
DROP VIEW Versions;
DROP VIEW Phones;
DROP VIEW File;


DROP FUNCTION IF EXISTS age/2;

SET DELIMITER @
CREATE FUNCTION age (
 asOf DATE,
 start DATE
) RETURNS STRING AS
 RETURN (
  SELECT CAST(DATEDIFF(YEAR, start, asOf) AS STRING) || ' years' FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS age/1;

SET DELIMITER @
CREATE FUNCTION age (
 start DATE
) RETURNS STRING AS
 RETURN (
  SELECT CAST(DATEDIFF(YEAR, start, NOW()) AS STRING) || ' years' FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;


DROP FUNCTION IF EXISTS days_until_birthday;
DROP FUNCTION IF EXISTS birthday/1;
DROP FUNCTION IF EXISTS birthday/2;

SET DELIMITER @
CREATE FUNCTION birthday (
 birth DATE,
 asOf DATE
) RETURNS STRING AS
 RETURN (
  SELECT
  CASE WHEN extract(month FROM birth) < extract(month FROM asOf) THEN
    (extract(year FROM asOf) + 1) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
  ELSE
   CASE WHEN extract(month FROM birth) = extract(month FROM asOf)
     AND extract(day FROM birth) < extract(day FROM asOf) THEN
    (extract(year FROM asOf) + 1) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
   ELSE
    extract(year FROM asOf) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
   END
  END AS birthday
  FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION birthday (
 birth DATE
) RETURNS STRING AS
 RETURN (
  SELECT birthday(birth, NOW()) FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE FUNCTION days_until_birthday (
 birth DATE,
 asOf DATE
) RETURNS INTEGER AS
 RETURN (
  SELECT DATEDIFF(DAY, asOf, birthday(birth)) FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

-- This should return the client culture state of the current connection or transaction
-- For now it just returns 1033,'en-US'
DROP FUNCTION IF EXISTS ClientCulture;

SET DELIMITER @
CREATE FUNCTION ClientCulture (
) RETURNS INTEGER AS
 RETURN (
 SELECT 1033
 FROM Dual
 );
END_FUNCTION;
@
SET DELIMITER ;

-- NuoDB does not have an interval type.
-- Will use an Integer in seconds instead.
-- Asume negative values for now

DROP FUNCTION IF EXISTS GetInterval;

SET DELIMITER @
CREATE FUNCTION GetInterval(
 interval_value STRING
) RETURNS INTEGER AS
 RETURN (
  SELECT datediff(SECOND, '1970-01-01 ' || interval_value, '1970-01-01') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE FUNCTION ClientNow (
) RETURNS TIMESTAMP AS
 RETURN NOW();
END_FUNCTION;
@
SET DELIMITER ;


-- Drop functions from procedures.sql
DROP FUNCTION IF EXISTS GetAddress;
DROP FUNCTION IF EXISTS GetAddress/3;
DROP FUNCTION IF EXISTS GetAddress/6;
DROP FUNCTION IF EXISTS AnonymousSession;
DROP FUNCTION IF EXISTS AnonymousSession/18;
DROP FUNCTION IF EXISTS AnonymousSession/6;
DROP FUNCTION IF EXISTS SetSession;
DROP FUNCTION IF EXISTS SetSession/7;
DROP FUNCTION IF EXISTS SetSession/22;
DROP FUNCTION IF EXISTS SetSession/23;
DROP FUNCTION IF EXISTS SetSession/8;
DROP FUNCTION IF EXISTS GetAssemblyApplicationRelease;
DROP FUNCTION IF EXISTS GetDeviceOSApplicationRelease/12;
DROP FUNCTION IF EXISTS GetAssemblyApplicationRelease/2;
DROP FUNCTION IF EXISTS GetDeviceOSApplicationRelease/3;
DROP FUNCTION IF EXISTS GetIdentifier;
DROP FUNCTION IF EXISTS GetPostal;
DROP FUNCTION IF EXISTS GetPostal/2;
DROP FUNCTION IF EXISTS GetPostal/3;
DROP FUNCTION IF EXISTS GetPostal/1;
DROP FUNCTION IF EXISTS GetPostal/9;
DROP FUNCTION IF EXISTS GetLocation;
DROP FUNCTION IF EXISTS GetVersionName;
DROP FUNCTION IF EXISTS GetVersionName/1;
DROP FUNCTION IF EXISTS GetVersionName/4;
DROP FUNCTION IF EXISTS GetRelease;
DROP FUNCTION IF EXISTS GetRelease/1;
DROP FUNCTION IF EXISTS GetRelease/2;
DROP FUNCTION IF EXISTS GetApplicationRelease;
DROP FUNCTION IF EXISTS GetApplication;
DROP FUNCTION IF EXISTS GetPartWithParent;
DROP FUNCTION IF EXISTS GetPartbySerial;
DROP FUNCTION IF EXISTS GetPart/2;
DROP FUNCTION IF EXISTS GetPart/1;
DROP FUNCTION IF EXISTS GetFile;
DROP FUNCTION IF EXISTS GetURL;
DROP FUNCTION IF EXISTS GetPath;
DROP FUNCTION IF EXISTS GetAgentString;
DROP FUNCTION IF EXISTS GetIdentityPhrase;
DROP FUNCTION IF EXISTS GetSentence;
DROP FUNCTION IF EXISTS GetSentence/1;
DROP FUNCTION IF EXISTS GetSentence/2;
DROP FUNCTION IF EXISTS SetSchemaVersion;
DROP FUNCTION IF EXISTS GetVersion;
DROP FUNCTION IF EXISTS GetWord;
DROP FUNCTION IF EXISTS GetWord/1;
DROP FUNCTION IF EXISTS GetWord/2;
DROP FUNCTION IF EXISTS ClientNow;

-- Drop tables that refer to themselves
DROP TABLE Part CASCADE;
DROP TABLE AssemblyApplicationRelease CASCADE;
DROP TABLE Location CASCADE;

