-- The MIT License (MIT) Copyright (c) 2017-2018 Stephen A Jazdzewski
-- Functions used in views
USE MyCo;

-- One-row table used by find-or-insert queries.
-- The name is reserved, so the table is quoted. Unquoted Dual is MySQL's dummy table.
DROP TABLE IF EXISTS `Dual`;
CREATE TABLE `Dual` (
 value INTEGER
);
INSERT INTO `Dual` (value) VALUES (NULL);

-- TODO Allow this to be set within a session
DROP FUNCTION IF EXISTS ClientCulture;
DELIMITER $$
CREATE FUNCTION ClientCulture (
) RETURNS SmallInt DETERMINISTIC
BEGIN
 RETURN ( 1033 );
END $$
DELIMITER ;
