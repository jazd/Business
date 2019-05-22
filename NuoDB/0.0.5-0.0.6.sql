-- NuoDB database schema version 0.0.5 to 0.0.6
--
SET DELIMITER @
CREATE OR REPLACE FUNCTION age (
 asOf DATE,
 start DATE
) RETURNS STRING DETERMINISTIC AS
 RETURN (
  SELECT CAST(DATEDIFF(YEAR, start, asOf) AS STRING) || ' years' FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION birthday (
 birth DATE,
 asOf DATE
) RETURNS STRING DETERMINISTIC AS
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
CREATE OR REPLACE FUNCTION days_until_birthday (
 birth DATE,
 asOf DATE
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
  SELECT DATEDIFF(DAY, asOf, birthday(birth)) FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION ClientCulture (
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
 SELECT 1033
 FROM Dual
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION GetInterval (
 interval_value STRING
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
  SELECT datediff(SECOND, '1970-01-01 ' || interval_value, '1970-01-01') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION Make_Date (
 inYear INTEGER,
 inMonth INTEGER,
 inDay INTEGER
) RETURNS DATE DETERMINISTIC AS
 RETURN DATE(inYear || '-' || inMonth || '-' || inDay);
END_FUNCTION;
@
SET DELIMITER ;
