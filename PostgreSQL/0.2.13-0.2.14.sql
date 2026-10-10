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
 COALESCE(SessionToken.created, Session.created) AS created, Session.touched
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
 Session.culture
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

-- Mark schema upgraded to 0.2.14 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.14 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '14');

COMMIT;
