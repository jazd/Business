-- The MIT License (MIT) Copyright (c) 2017-2018 Stephen A Jazdzewski
-- NuoDB has functions and procedures
-- These links may help
-- http://doc.nuodb.com/Latest/Content/CREATE-FUNCTION.htm
-- http://doc.nuodb.com/Latest/Content/CREATE-PROCEDURE.htm
-- Functions used in views

DROP FUNCTION IF EXISTS age;

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


DROP FUNCTION IF EXISTS birthday;

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

DROP FUNCTION IF EXISTS days_until_birthday;

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
