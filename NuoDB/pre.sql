-- The MIT License (MIT) Copyright (c) 2017 Stephen A Jazdzewski
-- NuoDB has functions and procedures
-- These links may help
-- http://doc.nuodb.com/Latest/Content/CREATE-FUNCTION.htm
-- http://doc.nuodb.com/Latest/Content/CREATE-PROCEDURE.htm

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
