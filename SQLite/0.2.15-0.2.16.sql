-- =============================================================================
-- Business schema upgrade: 0.2.15 -> 0.2.16 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.16 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.15.
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.15 (stop IS NULL)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.15 0.2.16
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.16) when STAMP_VERSION=1.
-- Leave STAMP_VERSION unset until that release.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

CREATE TABLE EntryDescription (
 id integer PRIMARY KEY AUTOINCREMENT,
 entry integer NOT NULL,
 description integer NOT NULL,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (entry) REFERENCES Entry (id)
);

CREATE UNIQUE INDEX entrydescription_entry_open
 ON EntryDescription (entry)
 WHERE stop IS NULL;

CREATE TABLE EntryReference (
 id integer PRIMARY KEY AUTOINCREMENT,
 entry integer NOT NULL,
 type integer,
 value varchar(80) NOT NULL,
 sequence smallint,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (entry) REFERENCES Entry (id)
);

CREATE UNIQUE INDEX entryreference_entry_type_open
 ON EntryReference (entry, type)
 WHERE stop IS NULL;

DROP VIEW IF EXISTS EntryDescriptions;
CREATE VIEW EntryDescriptions AS
SELECT
 EntryDescription.id,
 EntryDescription.entry,
 I18NSentence.value AS description,
 EntryDescription.created
FROM EntryDescription
JOIN I18NSentence ON I18NSentence.id = EntryDescription.description
WHERE EntryDescription.stop IS NULL;

DROP VIEW IF EXISTS EntryReferences;
CREATE VIEW EntryReferences AS
SELECT
 EntryReference.id,
 EntryReference.entry,
 COALESCE(RefIdent.value, RefWord.value) AS referenceType,
 EntryReference.value,
 EntryReference.sequence,
 EntryReference.created
FROM EntryReference
LEFT JOIN Word AS RefIdent ON RefIdent.id = EntryReference.type
 AND RefIdent.culture IS NULL
LEFT JOIN I18NWord AS RefWord ON RefWord.id = EntryReference.type
WHERE EntryReference.stop IS NULL;
