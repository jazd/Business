-- NuoDB database schema version 0.0.9 to 0.0.A
-- Changing IndividualList to ListIndividual
CREATE TABLE ListIndividual (
  id INTEGER,
  unlist TIMESTAMP,
  individual BIGINT NOT NULL,
  type INTEGER,
  created TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE ListIndividualName (
  listIndividual INTEGER GENERATED BY DEFAULT AS IDENTITY NOT NULL,
  name INTEGER NOT NULL,
  listSet INTEGER,
  sequence SMALLINT,
  optinStyle SMALLINT NOT NULL,
  created TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (listIndividual)
);

ALTER SEQUENCE LISTINDIVIDUALNAME$IDENTITY_SEQUENCE START WITH 2000000;

CREATE OR REPLACE VIEW List AS
SELECT ListIndividual.id,
 ListIndividual.individual,
 ListIndividualName.name AS listName,
 Name.value AS listNameValue,
 ListIndividualName.listSet,
 ListSet.value AS listSetValue,
 ListIndividualName.sequence,
 CASE WHEN SendField.value IS NULL THEN 'to' ELSE SendField.value END AS send,
 ListIndividual.created
FROM ListIndividual
JOIN ListIndividualName ON ListIndividualName.ListIndividual = ListIndividual.id
 AND ListIndividualName.optinStyle = 1
JOIN Word AS Name ON ListIndividualName.name = Name.id
 AND Name.culture = ClientCulture()
LEFT JOIN Word AS ListSet ON ListIndividualName.listSet = ListSet.id
 AND ListSet.culture = ClientCulture()
LEFT JOIN Word AS SendField ON SendField.id = ListIndividual.type
 AND SendField.culture IS NULL
LEFT JOIN ListIndividual AS disable ON disable.individual = ListIndividual.individual
 AND disable.id IS NULL
 AND disable.unlist IS NULL
WHERE disable.individual IS NULL
 AND ListIndividual.unlist IS NULL
;

INSERT INTO ListIndividual (id, unlist, individual, created)
SELECT id, unlist, individual, created FROM IndividualList;

INSERT INTO ListIndividualName (listIndividual, name, listSet, sequence, optinStyle, created)
SELECT individualList, name, listSet, sequence, optinStyle, created FROM IndividualListName;

DROP TABLE IndividualListName;
DROP TABLE IndividualList;

-- Email and List functions
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
 );
END_IF;
RETURN (
 SELECT id
 FROM Email
 WHERE UPPER(username) = UPPER(inUserName)
  AND UPPER(host) = UPPER(inHost)
  AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
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
  AND optinStyle = 1
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
 ;
END_IF;
RETURN inIndividual_id;
END_FUNCTION;
@
SET DELIMITER ;

DROP FUNCTION IF EXISTS SetIndividualEmail/2;
SET DELIMITER @
CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id INTEGER,
 inEmail_id INTEGER
) RETURNS INTEGER AS
RETURN SetIndividualEmail(inIndividual_id, inEmail_id, NULL);
END_FUNCTION;
@
SET DELIMITER ;

-- Bug fixes
DROP FUNCTION IF EXISTS GetIndividualPerson;

SET DELIMITER @
CREATE FUNCTION GetIndividualPerson (
 inFirst STRING,
 inMiddle STRING,
 inLast STRING,
 inBirth date, -- Can't be null
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
