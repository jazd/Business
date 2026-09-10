-- =============================================================================
-- Business schema upgrade: 0.2.10 -> 0.2.11 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.11 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.10 so it reaches the same end state as a fresh
-- 0.2.11 business.sqlite3 template (DDL + seeds that Static would add).
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.10 (stop IS NULL)
--   * File backup taken (script can .backup before apply)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.10 0.2.11
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.10 shop database)
-- ---------------------------------------------------------------------------
--
--  1) Bill.shipfrom / Bill.shipto (engine FKs via ADD COLUMN REFERENCES)
--  2) Location sqlite_sequence
--  3) Path.port (NULL on existing rows = default 80 / 443 in GetPath)
--  4) Recreate URL view with :port when Path.port is set
--  5) SessionToken.type; Word 18-20 session/mail/trial
--  6) IndividualSessionCreated already exists in the shop schema. PostgreSQL
--     SetSession writes it when inCredential has an individual. No shop Bash
--     SetSession; no SQLite DDL for this behavior.
--  7) IndividualSessions view (current individual to session across sites)
--  8) Unique active IndividualPath (individual, type, path); Bash Set/StopIndividualPath
--  9) SessionPath table; unique active (session, type, path); SessionURL;
--     Bash SetSessionPath / StopSessionPath
-- 10) ClaimSession is PostgreSQL-only (uses SetSession)
-- 11) PathPassword; unique unrevoked (path, password); Bash Set/RevokePathPassword
-- 12) Report views: IndividualSessions.siteName; IndividualPaths /
--     IndividualPathHistory; SessionPaths / SessionPathHistory; SiteMembership
--
-- SQLite does not enforce varchar(n). Email.host 30->96, Path.host 64->96,
-- and SessionToken.token 32->128 need no table rebuild; stored values stay.
-- IndividualURL is not in the SQLite template (SQLITE_UNSUPORTED_VIEWS).
-- SetSession remains PostgreSQL-only (no shop Bash port).
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.11) when STAMP_VERSION=1.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

ALTER TABLE Bill ADD COLUMN shipfrom INTEGER REFERENCES Address(id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE Bill ADD COLUMN shipto INTEGER REFERENCES Address(id) DEFERRABLE INITIALLY DEFERRED;

UPDATE sqlite_sequence SET seq = 20000 WHERE name = 'Location';

ALTER TABLE Path ADD COLUMN port smallint;

DROP VIEW IF EXISTS URL;
CREATE VIEW URL AS
SELECT id AS path, protocol, host,
 protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host ||
 CASE WHEN port IS NOT NULL THEN ':' || port ELSE '' END ||
 '/' ||
 COALESCE(value,'') ||
 CASE WHEN get IS NULL
 THEN ''
 ELSE '?' || get
 END AS value,
 created
FROM Path;

ALTER TABLE SessionToken ADD COLUMN type integer;

INSERT INTO Word (id, culture, value)
SELECT 18, 1033, 'session'
WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id = 18 AND culture = 1033);

INSERT INTO Word (id, culture, value)
SELECT 19, 1033, 'mail'
WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id = 19 AND culture = 1033);

INSERT INTO Word (id, culture, value)
SELECT 20, 1033, 'trial'
WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id = 20 AND culture = 1033);

DROP VIEW IF EXISTS IndividualSessions;
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
 SiteName.value AS siteName
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
DROP VIEW IF EXISTS IndividualPaths;
CREATE VIEW IndividualPaths AS
SELECT IndividualPath.individual,
 Type.value AS type,
 Path.id AS path,
 Path.protocol,
 Path.host,
 Path.protocol ||
 CASE WHEN Path.secure = 1 THEN 's' ELSE '' END ||
 '://' || Path.host ||
 CASE WHEN Path.port IS NOT NULL THEN ':' || Path.port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,IndividualPath.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND IndividualPath.track IS NOT  NULL) THEN '&' ELSE '' END || IndividualPath.track, '')
 END AS url,
 IndividualPath.created
FROM IndividualPath
JOIN Path ON Path.id = IndividualPath.path
LEFT JOIN I18NWord AS Type ON Type.id = IndividualPath.type
WHERE IndividualPath.stop IS NULL;
DROP VIEW IF EXISTS IndividualPathHistory;
CREATE VIEW IndividualPathHistory AS
SELECT IndividualPath.individual,
 Type.value AS type,
 Path.id AS path,
 Path.protocol,
 Path.host,
 Path.protocol ||
 CASE WHEN Path.secure = 1 THEN 's' ELSE '' END ||
 '://' || Path.host ||
 CASE WHEN Path.port IS NOT NULL THEN ':' || Path.port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,IndividualPath.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND IndividualPath.track IS NOT  NULL) THEN '&' ELSE '' END || IndividualPath.track, '')
 END AS url,
 IndividualPath.stop,
 IndividualPath.created
FROM IndividualPath
JOIN Path ON Path.id = IndividualPath.path
LEFT JOIN I18NWord AS Type ON Type.id = IndividualPath.type;
DROP VIEW IF EXISTS SiteMembership;
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



CREATE UNIQUE INDEX IF NOT EXISTS individualPath_individual_type_path_unstopped
 ON IndividualPath (individual, type, path)
 WHERE stop IS NULL;

CREATE TABLE IF NOT EXISTS SessionPath (
 session INTEGER NOT NULL,
 type INTEGER,
 path INTEGER,
 track varchar(30),
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (session) REFERENCES Session(id) DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY (path) REFERENCES Path(id) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX IF NOT EXISTS sessionpath_session_type ON SessionPath (session, type);

CREATE UNIQUE INDEX IF NOT EXISTS sessionPath_session_type_path_unstopped
 ON SessionPath (session, type, path)
 WHERE stop IS NULL;

DROP VIEW IF EXISTS SessionURL;
CREATE VIEW SessionURL AS
WITH latest AS (
 SELECT session, type, path, track, created,
  ROW_NUMBER() OVER (
   PARTITION BY session, type
   ORDER BY created DESC, path DESC
  ) AS rn
 FROM SessionPath
 WHERE stop IS NULL
)
SELECT latest.session, latest.type, Path.id AS path, Path.protocol, Path.host,
 Path.protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host ||
 CASE WHEN port IS NOT NULL THEN ':' || port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,latest.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND latest.track IS NOT  NULL) THEN '&' ELSE '' END ||  latest.track, '')
 END AS value,
 latest.created
FROM latest
JOIN Path ON Path.id = latest.path
WHERE latest.rn = 1;

DROP VIEW IF EXISTS SessionPaths;
CREATE VIEW SessionPaths AS
SELECT SessionPath.session,
 Type.value AS type,
 Path.id AS path,
 Path.protocol,
 Path.host,
 Path.protocol ||
 CASE WHEN Path.secure = 1 THEN 's' ELSE '' END ||
 '://' || Path.host ||
 CASE WHEN Path.port IS NOT NULL THEN ':' || Path.port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,SessionPath.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND SessionPath.track IS NOT  NULL) THEN '&' ELSE '' END || SessionPath.track, '')
 END AS url,
 SessionPath.created
FROM SessionPath
JOIN Path ON Path.id = SessionPath.path
LEFT JOIN I18NWord AS Type ON Type.id = SessionPath.type
WHERE SessionPath.stop IS NULL;
DROP VIEW IF EXISTS SessionPathHistory;
CREATE VIEW SessionPathHistory AS
SELECT SessionPath.session,
 Type.value AS type,
 Path.id AS path,
 Path.protocol,
 Path.host,
 Path.protocol ||
 CASE WHEN Path.secure = 1 THEN 's' ELSE '' END ||
 '://' || Path.host ||
 CASE WHEN Path.port IS NOT NULL THEN ':' || Path.port ELSE '' END ||
 '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,SessionPath.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND SessionPath.track IS NOT  NULL) THEN '&' ELSE '' END || SessionPath.track, '')
 END AS url,
 SessionPath.stop,
 SessionPath.created
FROM SessionPath
JOIN Path ON Path.id = SessionPath.path
LEFT JOIN I18NWord AS Type ON Type.id = SessionPath.type;


CREATE TABLE IF NOT EXISTS PathPassword (
 path INTEGER NOT NULL,
 password INTEGER NOT NULL,
 revoked timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (path) REFERENCES Path(id) DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY (password) REFERENCES Password(id) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX IF NOT EXISTS pathpassword_path ON PathPassword (path);

CREATE UNIQUE INDEX IF NOT EXISTS pathPassword_path_password_unrevoked
 ON PathPassword (path, password)
 WHERE revoked IS NULL;
