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


SET DELIMITER @
CREATE OR REPLACE FUNCTION AnonymousSession (
 inAgentString INTEGER,
 inRefSecure INTEGER,
 inRefHost STRING,
 inRefPath STRING,
 inRefGet STRING,
 inIPAddress STRING
) RETURNS BIGINT AS
 VAR existingSession BIGINT;
 VAR referringURL INTEGER;

 referringURL = (GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet));

 existingSession = (
  SELECT session
  FROM SessionCredential
  WHERE credential IS NULL
  AND agentString = inAgentString
  AND fromAddress = inIPAddress
  AND ((referring = referringURL) OR (referring IS NULL AND referringURL IS NULL))
 );

 IF (existingSession IS NULL)
  INSERT INTO Session ("lock") VALUES (0);
  existingSession = LAST_INSERT_ID();
  INSERT INTO SessionCredential (session,agentString,fromAddress,referring)
  SELECT existingSession AS session, inAgentString AS agentString,
   inIPAddress AS fromAddress, referringURL
  FROM Dual;
 ELSE
  UPDATE Session SET touched = NOW() WHERE id = existingSession;
 END_IF;

 RETURN existingSession;
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken STRING,
 inSiteApplicationRelease INTEGER,
 inAgentString INTEGER,
 inCredential INTEGER,
 inReferring INTEGER,
 inIPAddress STRING,
 inLocation INTEGER,
 inStart timestamp
) RETURNS BIGINT AS
 VAR existingSession BIGINT;
 IF (inSessionToken IS NOT NULL)
  existingSession = (
   SELECT session
   FROM SessionToken
   WHERE token = inSessionToken
    AND (
     (siteApplicationRelease = inSiteApplicationRelease)
      OR (siteApplicationRelease IS NULL AND inSiteApplicationRelease IS NULL)
    )
   LIMIT 1
  );

  IF (existingSession IS NULL)
   INSERT INTO Session ("lock") VALUES (0);
   existingSession = LAST_INSERT_ID();
   INSERT INTO SessionToken (session,token,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created FROM Dual
   );
  ELSE
   UPDATE Session SET touched = NOW() WHERE id = existingSession;
  END_IF;

  INSERT INTO SessionCredential (session, agentString, credential, referring, fromAddress, location) (
   SELECT existingSession, inAgentString, inCredential, inReferring, inIPAddress, inLocation
   FROM Dual
   LEFT JOIN SessionCredential AS does_exist ON does_exist.session = existingSession
    AND ((agentString = inAgentString) OR (agentString IS NULL AND inAgentString IS NULL))
    AND ((credential = inCredential) OR (credential IS NULL AND inCredential IS NULL))
    AND ((referring = inReferring) OR (referring IS NULL AND inReferring IS NULL))
    AND ((fromAddress = inIPAddress) OR (fromAddress IS NULL AND inIPAddress IS NULL))
    AND ((location = inLocation) OR (location IS NULL AND inLocation IS NULL))
   WHERE does_exist.id IS NULL
  );

 END_IF;
 RETURN existingSession;
END_FUNCTION;
@
SET DELIMITER ;


SET DELIMITER @
CREATE OR REPLACE FUNCTION SetSchemaVersion (
 inSchemaName STRING,
 inMajor STRING,
 inMinor STRING,
 inPatch STRING
) RETURNS INTEGER AS
 VAR schema_id INTEGER;
 VAR version_id INTEGER;
 IF (inSchemaName IS NOT NULL)
  schema_id = GetWord(inSchemaName);
  version_id = GetVersion(inMajor, inMinor, inPatch);
 END_IF;

 INSERT INTO SchemaVersion (schema, version) VALUES (schema_id, version_id);
 RETURN LAST_INSERT_ID();
END_FUNCTION;
@
SET DELIMITER ;
