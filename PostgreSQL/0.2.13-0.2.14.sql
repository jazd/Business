-- =============================================================================
-- Business schema upgrade: 0.2.13 -> 0.2.14 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.14 is unreleased. A database installed at
-- 0.2.13 reaches the same Email column widths as a fresh 0.2.14 build.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Active SchemaVersion is Business 0.2.13 (stop IS NULL)
--   * Email is in schema business, or in public when business has no Email
--   * Role can ALTER the table, DROP/CREATE views, and CREATE the unique index
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.13-0.2.14.sql
--
-- The script is one transaction. A failed statement rolls the views back.
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.13 database)
-- ---------------------------------------------------------------------------
--
--  1) Email.username and Email.plus become varchar(64). Email.host stays
--     varchar(96). Stored addresses are not rewritten.
--     A database that already has varchar(64) on both columns still runs:
--     the views are replaced and the type change is applied again.
--  2) email_username_plus_host is recreated on UPPER(username), UPPER(plus),
--     UPPER(host). View and index owners are the owners from before the drop.
--  3) Sessions and IndividualSessions gain SessionToken.timeout at the end.
--  4) GetSite, GetSiteApplicationRelease, GetCredential, PutPassword, and
--     SetSessionTimeout are created or replaced.
--  5) ContentElementAttributes lists unstopped format attributes on the
--     current edition. ClientCulture(varchar), FormatFor, ContentBody,
--     SiteContent, and ListContent are created or replaced.
--  6) Entitlement and EntitlementReference, views EntitlementHistory and
--     EntitlementCurrent, and EntitlementGrant, EntitlementSet,
--     EntitlementStop, and EntitlementReference.
--  7) SchemaVersions joins SchemaVersion to Versions. schemaName is the
--     I18NWord for schema. The version column is SchemaVersion.version.
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '14') - last substantive step
--
-- =============================================================================
\set ON_ERROR_STOP on

BEGIN;

SET search_path TO business, public;

DO $$
BEGIN
 IF to_regclass('email') IS NULL THEN
  RAISE EXCEPTION 'Email table not found';
 END IF;

 IF NOT EXISTS (
  SELECT true
  FROM schemaversion
  JOIN word AS schema ON schema.id = schemaversion.schema
  JOIN version ON version.id = schemaversion.version
  JOIN word AS major ON major.id = version.major
  JOIN word AS minor ON minor.id = version.minor
  JOIN word AS patch ON patch.id = version.patch
  WHERE schema.value = 'Business'
   AND major.value = '0'
   AND minor.value = '2'
   AND patch.value = '13'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.13';
 END IF;
END $$;

-- PostgreSQL refuses ALTER COLUMN TYPE while a view output uses that column.
-- EmailAddress reads Email.username and Email.plus. These views read EmailAddress.
DROP TABLE IF EXISTS email_widen_owner;
CREATE TEMP TABLE email_widen_owner (
 kind text NOT NULL,
 name text NOT NULL,
 owner name NOT NULL
);

INSERT INTO email_widen_owner (kind, name, owner)
SELECT 'view', c.relname, pg_get_userbyid(c.relowner)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.oid = (SELECT relnamespace FROM pg_class WHERE oid = to_regclass('email'))
 AND c.relkind = 'v'
 AND c.relname IN (
  'campaignrecipients',
  'individualemailaddress',
  'individualsessions',
  'sessions',
  'sitemembership',
  'emailaddress'
 );

INSERT INTO email_widen_owner (kind, name, owner)
SELECT 'index', c.relname, pg_get_userbyid(c.relowner)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.oid = (SELECT relnamespace FROM pg_class WHERE oid = to_regclass('email'))
 AND c.relkind = 'i'
 AND c.relname = 'email_username_plus_host';

DROP VIEW IF EXISTS CampaignRecipients;
DROP VIEW IF EXISTS IndividualEmailAddress;
DROP VIEW IF EXISTS IndividualSessions;
DROP VIEW IF EXISTS Sessions;
DROP VIEW IF EXISTS SiteMembership;
DROP VIEW IF EXISTS EmailAddress;

DROP INDEX IF EXISTS email_username_plus_host;

ALTER TABLE Email ALTER COLUMN username TYPE varchar(64);
ALTER TABLE Email ALTER COLUMN plus TYPE varchar(64);

CREATE UNIQUE INDEX email_username_plus_host
 ON Email (UPPER(username), UPPER(plus), UPPER(host));

CREATE VIEW EmailAddress AS
SELECT id AS email, username, plus, host,
 username ||
 COALESCE('+' || plus, '') ||
 '@' || host AS value
FROM Email;

CREATE VIEW SiteMembership AS
SELECT ListIndividual.individual,
 EmailAddress.value AS email,
 Name.value AS listNameValue,
 ListSet.value AS listSetValue,
 ListIndividual.unlist,
 ListIndividual.created
FROM ListIndividual
LEFT JOIN ListIndividualName ON ListIndividualName.listIndividual = ListIndividual.id
LEFT JOIN I18NWord AS Name ON Name.id = ListIndividualName.name
LEFT JOIN I18NWord AS ListSet ON ListSet.id = ListIndividualName.listSet
LEFT JOIN IndividualEmail ON IndividualEmail.individual = ListIndividual.individual
 AND IndividualEmail.stop IS NULL
 AND IndividualEmail.type IS NULL
LEFT JOIN EmailAddress ON EmailAddress.email = IndividualEmail.email;

CREATE VIEW CampaignRecipients AS
SELECT Campaign.id AS campaign,
 ListIndividual.individual,
 EmailAddress.value AS email,
 IndividualAddress.address
FROM Campaign
JOIN ListIndividualName ON ListIndividualName.name = Campaign.listName
 AND (Campaign.listSet IS NULL OR ListIndividualName.listSet = Campaign.listSet)
JOIN ListIndividual ON ListIndividual.id = ListIndividualName.listIndividual
 AND ListIndividual.unlist IS NULL
LEFT JOIN IndividualEmail ON IndividualEmail.individual = ListIndividual.individual
 AND IndividualEmail.stop IS NULL
 AND IndividualEmail.type IS NULL
LEFT JOIN EmailAddress ON EmailAddress.email = IndividualEmail.email
LEFT JOIN IndividualAddress ON IndividualAddress.individual = ListIndividual.individual
 AND IndividualAddress.stop IS NULL
 AND IndividualAddress.type IS NULL;

CREATE VIEW IndividualEmailAddress AS
WITH latest (individual, type, created) AS (
 SELECT individual, type, MAX(created) AS created
 FROM IndividualEmail
 WHERE IndividualEmail.stop IS NULL
 GROUP BY individual, type
)
SELECT latest.individual, latest.type, IndividualEmail.email, EmailAddress.username,
 EmailAddress.plus, EmailAddress.host, EmailAddress.value, latest.created
FROM latest
JOIN Individual ON Individual.id = latest.individual
 AND Individual.nameChange IS NULL
JOIN IndividualEmail ON IndividualEmail.individual = latest.individual
 AND IndividualEmail.type = latest.type
 AND IndividualEmail.created = latest.created
JOIN EmailAddress ON EmailAddress.email = IndividualEmail.email;

CREATE VIEW Sessions AS
SELECT Session.id AS session,
 SessionToken.token, SessionToken.siteapplicationrelease,
 SessionCredential.agentstring,
 deviceid, ParsedAgentStringShort.device, osid, ParsedAgentStringShort.os, agentid, ParsedAgentStringShort.agent,
 SessionCredential.referring, URL.value AS referrringURL,
 SessionCredential.fromaddress,
 SessionCredential.credential, Credential.individual, Credential.username,
 EmailAddress.value AS email,
 COALESCE(SessionToken.created, Session.created) AS created, Session.touched,
 SessionToken.timeout
FROM Session
CROSS JOIN SessionCredential
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN ParsedAgentStringShort ON ParsedAgentStringShort.agentstring = SessionCredential.agentstring
LEFT JOIN Credential ON Credential.id = SessionCredential.credential
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email
LEFT JOIN URL ON URL.path = SessionCredential.referring
WHERE Session.id = SessionCredential.session;

CREATE VIEW IndividualSessions AS
WITH bound (individual, sessionCredential, bound) AS (
 SELECT individual, sessionCredential, created
 FROM IndividualSessionCreated
 UNION
 SELECT Credential.individual, SessionCredential.id, SessionCredential.created
 FROM SessionCredential
 JOIN Credential ON Credential.id = SessionCredential.credential
  AND Credential.revoked IS NULL
  AND Credential.individual IS NOT NULL
)
SELECT
 bound.individual,
 COALESCE(People.fullName, Entities.name) AS individualName,
 Session.id AS session,
 SessionToken.token,
 Type.value AS tokenType,
 SessionToken.siteApplicationRelease,
 Site.id AS site,
 SessionCredential.id AS sessionCredential,
 SessionCredential.credential,
 Credential.username,
 EmailAddress.value AS email,
 bound.bound,
 Session.touched,
 COALESCE(SessionToken.created, Session.created) AS created,
 SiteName.value AS siteName,
 Session.culture,
 SessionToken.timeout
FROM bound
JOIN SessionCredential ON SessionCredential.id = bound.sessionCredential
JOIN Session ON Session.id = SessionCredential.session
JOIN Credential ON Credential.id = SessionCredential.credential
 AND Credential.revoked IS NULL
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN I18NWord AS Type ON Type.id = SessionToken.type
LEFT JOIN SiteApplicationRelease ON SiteApplicationRelease.id = SessionToken.siteApplicationRelease
LEFT JOIN Site ON Site.id = SiteApplicationRelease.site
LEFT JOIN I18NSentence AS SiteName ON SiteName.id = Site.name
LEFT JOIN People ON People.individual = bound.individual
LEFT JOIN Entities ON Entities.individual = bound.individual
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email;

DO $$
DECLARE
 rec record;
BEGIN
 FOR rec IN SELECT kind, name, owner FROM email_widen_owner LOOP
  IF rec.kind = 'view' THEN
   EXECUTE format('ALTER VIEW %I OWNER TO %I', rec.name, rec.owner);
  ELSIF rec.kind = 'index' THEN
   EXECUTE format('ALTER INDEX %I OWNER TO %I', rec.name, rec.owner);
  END IF;
 END LOOP;
END $$;

-- GetSite stores a Sentence id in Site.name.
CREATE OR REPLACE FUNCTION GetSite (
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 site_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  SELECT id INTO site_id
  FROM Site
  WHERE name = name_id
  LIMIT 1;
  IF site_id IS NULL THEN
   PERFORM pg_advisory_lock(name_id);
   BEGIN
   INSERT INTO Site (name) (
    SELECT name_id AS name
    FROM Dual
    LEFT JOIN Site AS exists ON exists.name = name_id
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(name_id);
     RAISE;
   END;
   SELECT id INTO site_id
   FROM Site
   WHERE name = name_id
   LIMIT 1;
  END IF;
 END IF;
 RETURN site_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetSiteApplicationRelease (
 inSite integer,
 inApplicationRelease integer
) RETURNS integer AS $$
DECLARE
 siteApplicationRelease_id integer;
BEGIN
 IF inSite IS NOT NULL AND inApplicationRelease IS NOT NULL THEN
  SELECT id INTO siteApplicationRelease_id
  FROM SiteApplicationRelease
  WHERE site = inSite
   AND applicationRelease = inApplicationRelease
  LIMIT 1;
  IF siteApplicationRelease_id IS NULL THEN
   PERFORM pg_advisory_lock(inSite);
   BEGIN
   INSERT INTO SiteApplicationRelease (site, applicationRelease) (
    SELECT inSite AS site, inApplicationRelease AS applicationRelease
    FROM Dual
    LEFT JOIN SiteApplicationRelease AS exists
     ON exists.site = inSite
     AND exists.applicationRelease = inApplicationRelease
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inSite);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inSite);
     RAISE;
   END;
   SELECT id INTO siteApplicationRelease_id
   FROM SiteApplicationRelease
   WHERE site = inSite
    AND applicationRelease = inApplicationRelease
   LIMIT 1;
  END IF;
 END IF;
 RETURN siteApplicationRelease_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION PutPassword (
 inValue text
) RETURNS integer AS $$
DECLARE
 password_id integer;
BEGIN
 INSERT INTO Password (value) VALUES (inValue) RETURNING id INTO password_id;
 RETURN password_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetCredential (
 inIndividual bigint,
 inEmail integer
) RETURNS integer AS $$
DECLARE
 credential_id integer;
BEGIN
 IF inIndividual IS NOT NULL AND inEmail IS NOT NULL THEN
  SELECT id INTO credential_id
  FROM Credential
  WHERE individual = inIndividual
   AND email = inEmail
   AND revoked IS NULL
  LIMIT 1;
  IF credential_id IS NULL THEN
   PERFORM pg_advisory_lock(inIndividual);
   BEGIN
   INSERT INTO Credential (individual, email) (
    SELECT inIndividual, inEmail
    FROM Dual
    LEFT JOIN Credential AS exists ON exists.individual = inIndividual
     AND exists.email = inEmail
     AND exists.revoked IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inIndividual);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inIndividual);
     RAISE;
   END;
   SELECT id INTO credential_id
   FROM Credential
   WHERE individual = inIndividual
    AND email = inEmail
    AND revoked IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN credential_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSessionTimeout (
 inToken varchar,
 inSiteApplicationRelease integer,
 inSeconds integer
) RETURNS integer AS $$
DECLARE
 filled integer;
BEGIN
 IF inToken IS NULL OR inSeconds IS NULL THEN
  RETURN 0;
 END IF;
 UPDATE SessionToken
 SET timeout = inSeconds
 WHERE token = inToken
  AND (
   (siteApplicationRelease = inSiteApplicationRelease)
    OR (siteApplicationRelease IS NULL AND inSiteApplicationRelease IS NULL)
  )
  AND timeout IS NULL;
 GET DIAGNOSTICS filled = ROW_COUNT;
 RETURN filled;
END;
$$ LANGUAGE plpgsql;

DROP VIEW IF EXISTS ContentElementAttributes;
CREATE VIEW ContentElementAttributes AS
SELECT ContentElements.content,
 ContentElements.edition,
 ContentElements.sequence,
 ContentElements.kind,
 ContentElements.element,
 ContentElements.value,
 ContentElements.format,
 FormatAttributes.name,
 FormatAttributes.value AS attribute,
 FormatAttributes.target
FROM ContentElements
JOIN FormatAttributes ON FormatAttributes.format = ContentElements.format;

-- ClientCulture(name varchar) sets inject_culture for this connection.
-- NULL clears it. An unknown name leaves the current culture in place.
CREATE OR REPLACE FUNCTION ClientCulture (
 inName varchar
) RETURNS smallint AS $$
DECLARE
 culture_code smallint;
BEGIN
 SET LOCAL client_min_messages=warning;
 CREATE TEMP TABLE IF NOT EXISTS inject_culture (
  value smallint
 );
 RESET client_min_messages;
 IF inName IS NULL THEN
  DELETE FROM inject_culture;
 ELSE
  SELECT code INTO culture_code
  FROM Culture
  WHERE UPPER(name) = UPPER(inName);
  IF culture_code IS NOT NULL THEN
   DELETE FROM inject_culture;
   INSERT INTO inject_culture (value) VALUES (culture_code);
  END IF;
 END IF;
 RETURN ClientCulture();
END;
$$ LANGUAGE plpgsql;


-- FormatFor(format integer, target varchar).
-- A row whose target word matches inTarget wins over a null target of the same name.
CREATE OR REPLACE FUNCTION FormatFor (
 inFormat integer,
 inTarget varchar
) RETURNS TABLE (
 name varchar,
 value varchar
) AS $$
BEGIN
 IF inFormat IS NULL THEN
  RETURN;
 END IF;
 RETURN QUERY
 SELECT AttrName.value,
  AttrValue.value
 FROM FormatAttribute
 LEFT JOIN I18NWord AS AttrName ON AttrName.id = FormatAttribute.name
 LEFT JOIN I18NWord AS AttrValue ON AttrValue.id = FormatAttribute.value
 LEFT JOIN I18NWord AS AttrTarget ON AttrTarget.id = FormatAttribute.target
 WHERE FormatAttribute.format = inFormat
  AND FormatAttribute.stop IS NULL
  AND (
   (
    inTarget IS NOT NULL
    AND FormatAttribute.target IS NOT NULL
    AND UPPER(AttrTarget.value) = UPPER(inTarget)
   )
   OR (
    FormatAttribute.target IS NULL
    AND (
     inTarget IS NULL
     OR NOT EXISTS (
      SELECT 1
      FROM FormatAttribute AS specific
      LEFT JOIN I18NWord AS SpecificTarget ON SpecificTarget.id = specific.target
      WHERE specific.format = FormatAttribute.format
       AND specific.name = FormatAttribute.name
       AND specific.stop IS NULL
       AND specific.target IS NOT NULL
       AND UPPER(SpecificTarget.value) = UPPER(inTarget)
     )
    )
   )
  );
END;
$$ LANGUAGE plpgsql;

-- ContentBody(content integer, target varchar).
-- Current edition. An element with no winning attribute is one row with a null name.
CREATE OR REPLACE FUNCTION ContentBody (
 inContent integer,
 inTarget varchar
) RETURNS TABLE (
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar
) AS $$
BEGIN
 RETURN QUERY
 SELECT ContentElements.sequence,
  ContentElements.kind::varchar,
  ContentElements.element,
  ContentElements.value::varchar,
  ContentElements.format,
  ContentElements.argument::varchar,
  winning.name,
  winning.attribute
 FROM ContentElements
 LEFT JOIN LATERAL (
  SELECT FormatFor.name,
   FormatFor.value AS attribute
  FROM FormatFor(ContentElements.format, inTarget)
 ) AS winning ON true
 WHERE ContentElements.content = inContent
 ORDER BY ContentElements.sequence, winning.name;
END;
$$ LANGUAGE plpgsql;

-- SiteContent(site integer, target varchar).
-- Unstopped ContentSite rows, placement sequence then element sequence.
CREATE OR REPLACE FUNCTION SiteContent (
 inSite integer,
 inTarget varchar
) RETURNS TABLE (
 place integer,
 content integer,
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar
) AS $$
BEGIN
 RETURN QUERY
 SELECT ContentSites.sequence,
  ContentSites.content,
  body.sequence,
  body.kind,
  body.element,
  body.value,
  body.format,
  body.argument,
  body.name,
  body.attribute
 FROM ContentSites
 JOIN LATERAL ContentBody(ContentSites.content, inTarget) AS body ON true
 WHERE ContentSites.site = inSite
 ORDER BY ContentSites.sequence, body.sequence, body.name;
END;
$$ LANGUAGE plpgsql;

-- ListContent(list name varchar, target varchar).
-- Unstopped ContentList rows for that list name. Does not create the word.
CREATE OR REPLACE FUNCTION ListContent (
 inListName varchar,
 inTarget varchar
) RETURNS TABLE (
 place integer,
 content integer,
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar
) AS $$
DECLARE
 list_id integer;
BEGIN
 IF inListName IS NULL THEN
  RETURN;
 END IF;
 SELECT Word.id INTO list_id
 FROM Word
 WHERE Word.culture = 1033
  AND UPPER(Word.value) = UPPER(inListName)
 LIMIT 1;
 IF list_id IS NULL THEN
  RETURN;
 END IF;
 RETURN QUERY
 SELECT ContentList.sequence,
  ContentList.content,
  body.sequence,
  body.kind,
  body.element,
  body.value,
  body.format,
  body.argument,
  body.name,
  body.attribute
 FROM ContentList
 JOIN LATERAL ContentBody(ContentList.content, inTarget) AS body ON true
 WHERE ContentList.listName = list_id
  AND ContentList.stop IS NULL
 ORDER BY ContentList.sequence, body.sequence, body.name;
END;
$$ LANGUAGE plpgsql;


CREATE TABLE IF NOT EXISTS Entitlement (
 id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 individual bigint NOT NULL,
 listName integer NOT NULL,
 listSet integer,
 source integer NOT NULL,
 status integer NOT NULL,
 starts timestamp NOT NULL,
 ends timestamp,
 batch integer,
 stopReason integer,
 stopped timestamp,
 created timestamp NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS entitlement_individual ON Entitlement (individual);
CREATE UNIQUE INDEX IF NOT EXISTS entitlement_current_set
 ON Entitlement (individual, listName, listSet, source)
 WHERE stopped IS NULL AND listSet IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS entitlement_current_noset
 ON Entitlement (individual, listName, source)
 WHERE stopped IS NULL AND listSet IS NULL;

CREATE TABLE IF NOT EXISTS EntitlementReference (
 id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 entitlement integer NOT NULL REFERENCES Entitlement (id) DEFERRABLE,
 name integer NOT NULL,
 value text NOT NULL,
 created timestamp NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS entitlementreference_entitlement_name
 ON EntitlementReference (entitlement, name);

DROP VIEW IF EXISTS EntitlementCurrent;
DROP VIEW IF EXISTS EntitlementHistory;

CREATE VIEW EntitlementHistory AS
SELECT Entitlement.id,
 Entitlement.individual,
 Entitlement.listName,
 ListName.value AS listNameValue,
 Entitlement.listSet,
 ListSet.value AS listSetValue,
 Entitlement.source,
 Source.value AS sourceValue,
 Entitlement.status,
 Status.value AS statusValue,
 Entitlement.stopReason,
 StopReason.value AS stopReasonValue,
 Entitlement.starts,
 Entitlement.ends,
 Entitlement.batch,
 Batch.value AS batchValue,
 Entitlement.stopped,
 Entitlement.created
FROM Entitlement
LEFT JOIN I18NWord AS ListName ON ListName.id = Entitlement.listName
LEFT JOIN I18NWord AS ListSet ON ListSet.id = Entitlement.listSet
LEFT JOIN I18NWord AS Source ON Source.id = Entitlement.source
LEFT JOIN I18NWord AS Status ON Status.id = Entitlement.status
LEFT JOIN I18NWord AS StopReason ON StopReason.id = Entitlement.stopReason
LEFT JOIN I18NSentence AS Batch ON Batch.id = Entitlement.batch;

CREATE VIEW EntitlementCurrent AS
SELECT Entitlement.id,
 Entitlement.individual,
 Entitlement.listName,
 ListName.value AS listNameValue,
 Entitlement.listSet,
 ListSet.value AS listSetValue,
 Entitlement.source,
 Source.value AS sourceValue,
 Entitlement.status,
 Status.value AS statusValue,
 Entitlement.stopReason,
 StopReason.value AS stopReasonValue,
 Entitlement.starts,
 Entitlement.ends,
 Entitlement.batch,
 Batch.value AS batchValue,
 Entitlement.stopped,
 Entitlement.created
FROM Entitlement
LEFT JOIN I18NWord AS ListName ON ListName.id = Entitlement.listName
LEFT JOIN I18NWord AS ListSet ON ListSet.id = Entitlement.listSet
LEFT JOIN I18NWord AS Source ON Source.id = Entitlement.source
LEFT JOIN I18NWord AS Status ON Status.id = Entitlement.status
LEFT JOIN I18NWord AS StopReason ON StopReason.id = Entitlement.stopReason
LEFT JOIN I18NSentence AS Batch ON Batch.id = Entitlement.batch
WHERE Entitlement.stopped IS NULL
 AND (Entitlement.ends IS NULL OR Entitlement.ends > ClientNow());

-- Entitlement — one version of a period. stopped IS NULL is current.
-- These procedures do not subscribe or unlist.

-- EntitlementGrant returns the current row for this individual, list, set, and source.
-- It inserts one when there is none.
CREATE OR REPLACE FUNCTION EntitlementGrant (
 inIndividual bigint,
 inListName varchar,
 inListSet varchar,
 inSource varchar,
 inStatus varchar,
 inStarts timestamp,
 inEnds timestamp,
 inBatch varchar
) RETURNS integer AS $$
DECLARE
 list_id integer;
 set_id integer;
 source_id integer;
 status_id integer;
 batch_id integer;
 entitlement_id integer;
BEGIN
 IF inIndividual IS NULL OR inListName IS NULL OR inSource IS NULL
  OR inStatus IS NULL OR inStarts IS NULL THEN
  RETURN NULL;
 END IF;
 list_id := (SELECT GetWord(inListName));
 source_id := (SELECT GetWord(inSource));
 status_id := (SELECT GetWord(inStatus));
 IF inListSet IS NOT NULL THEN
  set_id := (SELECT GetWord(inListSet));
 END IF;
 IF inBatch IS NOT NULL THEN
  batch_id := (SELECT GetSentence(inBatch));
 END IF;
 SELECT id INTO entitlement_id
 FROM Entitlement
 WHERE individual = inIndividual
  AND listName = list_id
  AND source = source_id
  AND stopped IS NULL
  AND (
   (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
  )
 LIMIT 1;
 IF entitlement_id IS NULL THEN
  PERFORM pg_advisory_lock(inIndividual);
  BEGIN
   INSERT INTO Entitlement (
    individual, listName, listSet, source, status, starts, ends, batch
   ) (
    SELECT inIndividual, list_id, set_id, source_id, status_id,
     inStarts, inEnds, batch_id
    FROM Dual
    LEFT JOIN Entitlement AS exists
     ON exists.individual = inIndividual
     AND exists.listName = list_id
     AND exists.source = source_id
     AND exists.stopped IS NULL
     AND (
      (exists.listSet = set_id) OR (exists.listSet IS NULL AND set_id IS NULL)
     )
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inIndividual);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inIndividual);
    RAISE;
  END;
  SELECT id INTO entitlement_id
  FROM Entitlement
  WHERE individual = inIndividual
   AND listName = list_id
   AND source = source_id
   AND stopped IS NULL
   AND (
    (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
   )
  LIMIT 1;
 END IF;
 RETURN entitlement_id;
END;
$$ LANGUAGE plpgsql;

-- EntitlementSet stops the current row with reason replaced and inserts the next version.
CREATE OR REPLACE FUNCTION EntitlementSet (
 inIndividual bigint,
 inListName varchar,
 inListSet varchar,
 inSource varchar,
 inStatus varchar,
 inStarts timestamp,
 inEnds timestamp,
 inBatch varchar
) RETURNS integer AS $$
DECLARE
 list_id integer;
 set_id integer;
 source_id integer;
 status_id integer;
 batch_id integer;
 reason_id integer;
 entitlement_id integer;
BEGIN
 IF inIndividual IS NULL OR inListName IS NULL OR inSource IS NULL
  OR inStatus IS NULL OR inStarts IS NULL THEN
  RETURN NULL;
 END IF;
 list_id := (SELECT GetWord(inListName));
 source_id := (SELECT GetWord(inSource));
 status_id := (SELECT GetWord(inStatus));
 reason_id := (SELECT GetWord('replaced'));
 IF inListSet IS NOT NULL THEN
  set_id := (SELECT GetWord(inListSet));
 END IF;
 IF inBatch IS NOT NULL THEN
  batch_id := (SELECT GetSentence(inBatch));
 END IF;
 PERFORM pg_advisory_lock(inIndividual);
 BEGIN
  UPDATE Entitlement
  SET stopped = NOW(),
   stopReason = reason_id
  WHERE individual = inIndividual
   AND listName = list_id
   AND source = source_id
   AND stopped IS NULL
   AND (
    (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
   );
  INSERT INTO Entitlement (
   individual, listName, listSet, source, status, starts, ends, batch
  ) VALUES (
   inIndividual, list_id, set_id, source_id, status_id,
   inStarts, inEnds, batch_id
  ) RETURNING id INTO entitlement_id;
  PERFORM pg_advisory_unlock(inIndividual);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(inIndividual);
   RAISE;
 END;
 RETURN entitlement_id;
END;
$$ LANGUAGE plpgsql;

-- EntitlementStop sets stopped and stopReason on the current row.
CREATE OR REPLACE FUNCTION EntitlementStop (
 inIndividual bigint,
 inListName varchar,
 inListSet varchar,
 inSource varchar,
 inStopReason varchar
) RETURNS integer AS $$
DECLARE
 list_id integer;
 set_id integer;
 source_id integer;
 reason_id integer;
 entitlement_id integer;
BEGIN
 IF inIndividual IS NULL OR inListName IS NULL OR inSource IS NULL THEN
  RETURN NULL;
 END IF;
 list_id := (SELECT GetWord(inListName));
 source_id := (SELECT GetWord(inSource));
 IF inListSet IS NOT NULL THEN
  set_id := (SELECT GetWord(inListSet));
 END IF;
 IF inStopReason IS NOT NULL THEN
  reason_id := (SELECT GetWord(inStopReason));
 END IF;
 UPDATE Entitlement
 SET stopped = NOW(),
  stopReason = reason_id
 WHERE individual = inIndividual
  AND listName = list_id
  AND source = source_id
  AND stopped IS NULL
  AND (
   (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
  )
 RETURNING id INTO entitlement_id;
 RETURN entitlement_id;
END;
$$ LANGUAGE plpgsql;

-- EntitlementReference stores one name and value on a version.
-- The same name on that version returns the existing row.
CREATE OR REPLACE FUNCTION EntitlementReference (
 inEntitlement integer,
 inName varchar,
 inValue text
) RETURNS integer AS $$
DECLARE
 name_id integer;
 reference_id integer;
BEGIN
 IF inEntitlement IS NULL OR inName IS NULL OR inValue IS NULL THEN
  RETURN NULL;
 END IF;
 name_id := (SELECT GetWord(inName));
 SELECT id INTO reference_id
 FROM EntitlementReference
 WHERE entitlement = inEntitlement
  AND name = name_id
 LIMIT 1;
 IF reference_id IS NULL THEN
  PERFORM pg_advisory_lock(inEntitlement);
  BEGIN
   INSERT INTO EntitlementReference (entitlement, name, value) (
    SELECT inEntitlement, name_id, inValue
    FROM Dual
    LEFT JOIN EntitlementReference AS exists
     ON exists.entitlement = inEntitlement
     AND exists.name = name_id
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inEntitlement);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inEntitlement);
    RAISE;
  END;
  SELECT id INTO reference_id
  FROM EntitlementReference
  WHERE entitlement = inEntitlement
   AND name = name_id
  LIMIT 1;
 END IF;
 RETURN reference_id;
END;
$$ LANGUAGE plpgsql;

DROP VIEW IF EXISTS SchemaVersions;
CREATE VIEW SchemaVersions AS
SELECT SchemaVersion.build,
 SchemaVersion.schema,
 SchemaName.value AS schemaName,
 SchemaVersion.version,
 SchemaVersion.stop,
 SchemaVersion.created,
 Versions.name,
 Versions.value,
 Versions.major,
 Versions.minor,
 Versions.patch
FROM SchemaVersion
JOIN Versions ON SchemaVersion.version = Versions.version
LEFT JOIN I18NWord AS SchemaName ON SchemaName.id = SchemaVersion.schema;

-- Mark schema upgraded to 0.2.14 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.14 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '14');

COMMIT;
