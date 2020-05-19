-- The MIT License (MIT) Copyright (c) 2017-2018 Stephen A Jazdzewski
-- Functions used in views
USE Business;

-- TODO Allow this to be set within a session
DROP FUNCTION IF EXISTS ClientCulture;
DELIMITER $$
CREATE FUNCTION ClientCulture (
) RETURNS SmallInt DETERMINISTIC
BEGIN
 RETURN ( 1033 );
END $$
DELIMITER ;
