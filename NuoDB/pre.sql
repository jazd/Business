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
