-- =============================================================================
-- Business schema upgrade: 0.2.13 -> 0.2.14 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.14 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.13.
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.13 (stop IS NULL)
--   * File backup taken (script can .backup before apply)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.13 0.2.14
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.13 shop database)
-- ---------------------------------------------------------------------------
--
--  1) Email.username and Email.plus are varchar(64) in schema.xml.
--     Email.host stays varchar(96).
--  2) ContentElementAttributes lists unstopped format attributes on the
--     current edition. The read procedures are PostgreSQL.
--
-- SQLite does not enforce varchar(n). Email.username and Email.plus 30->64
-- need no table rebuild; stored values stay.
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.14) when STAMP_VERSION=1.
-- Leave STAMP_VERSION unset until that release.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

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
