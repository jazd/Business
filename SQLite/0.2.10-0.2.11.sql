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
 COALESCE(SessionToken.created, Session.created) AS created
FROM bound
JOIN SessionCredential ON SessionCredential.id = bound.sessionCredential
JOIN Session ON Session.id = SessionCredential.session
JOIN Credential ON Credential.id = SessionCredential.credential
 AND Credential.revoked IS NULL
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN I18NWord AS Type ON Type.id = SessionToken.type
LEFT JOIN SiteApplicationRelease ON SiteApplicationRelease.id = SessionToken.siteApplicationRelease
LEFT JOIN Site ON Site.id = SiteApplicationRelease.site
LEFT JOIN People ON People.individual = bound.individual
LEFT JOIN Entities ON Entities.individual = bound.individual
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email;
