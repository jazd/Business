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
--  3) Entitlement and EntitlementReference, plus EntitlementHistory and
--     EntitlementCurrent. The writer procedures are PostgreSQL.
--  4) SchemaVersions joins SchemaVersion to Versions. schemaName is the
--     I18NWord for schema. The version column is SchemaVersion.version.
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

CREATE TABLE IF NOT EXISTS Entitlement (
 id INTEGER PRIMARY KEY,
 individual integer NOT NULL,
 listName integer NOT NULL,
 listSet integer,
 source integer NOT NULL,
 status integer NOT NULL,
 starts timestamp NOT NULL,
 ends timestamp,
 batch integer,
 stopReason integer,
 stopped timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS entitlement_individual ON Entitlement (individual);
CREATE UNIQUE INDEX IF NOT EXISTS entitlement_current_set
 ON Entitlement (individual, listName, listSet, source)
 WHERE stopped IS NULL AND listSet IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS entitlement_current_noset
 ON Entitlement (individual, listName, source)
 WHERE stopped IS NULL AND listSet IS NULL;

CREATE TABLE IF NOT EXISTS EntitlementReference (
 id INTEGER PRIMARY KEY,
 entitlement integer NOT NULL REFERENCES Entitlement(id),
 name integer NOT NULL,
 value text NOT NULL,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
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
