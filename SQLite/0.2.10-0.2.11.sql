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
--
-- SQLite does not enforce varchar(n). Email.host 30->96, Path.host 64->96,
-- and SessionToken.token 32->128 need no table rebuild; stored values stay.
-- IndividualURL is not in the SQLite template (SQLITE_UNSUPORTED_VIEWS).
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
