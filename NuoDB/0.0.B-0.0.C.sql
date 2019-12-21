-- NuoDB database schema version 0.0.B to 0.0.C
-- Allow for addresses without states
ALTER TABLE Postal CHANGE COLUMN state state INTEGER NULL;

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
