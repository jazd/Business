-- =============================================================================
-- Business schema upgrade: 0.2.15 -> 0.2.16 (SQLite shop)
-- =============================================================================
--
-- Released hop 0.2.15 -> 0.2.16. Apply to a shop DB that was
-- built or upgraded to 0.2.15. Living work for the next version is
-- SQLite/0.2.16-0.2.17.sql.
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
-- after this file runs successfully (Business 0.2.16).
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

-- Triggers for Word, Sentence and Paragraph.
-- id is not the primary key, so a new row defaults to 0.
-- The next id is at least 2000000, and above any id already stored.
DROP TRIGGER IF EXISTS auto_increment_sequence_word;
CREATE TRIGGER auto_increment_sequence_word
AFTER INSERT ON word
WHEN new.id = 0
BEGIN
    UPDATE word
    SET id = (
      SELECT MAX(IFNULL(MAX(id), 0) + 1, 2000000) FROM word
    )
    WHERE rowid = new.rowid;
END;

DROP TRIGGER IF EXISTS auto_increment_sequence_sentence;
CREATE TRIGGER auto_increment_sequence_sentence
AFTER INSERT ON sentence
WHEN new.id = 0
BEGIN
    UPDATE sentence
    SET id = (
      SELECT MAX(IFNULL(MAX(id), 0) + 1, 2000000) FROM sentence
    )
    WHERE rowid = new.rowid;
END;

DROP TRIGGER IF EXISTS auto_increment_sequence_paragraph;
CREATE TRIGGER auto_increment_sequence_paragraph
AFTER INSERT ON paragraph
WHEN new.id = 0
BEGIN
    UPDATE paragraph
    SET id = (
      SELECT MAX(IFNULL(MAX(id), 0) + 1, 2000000) FROM paragraph
    )
    WHERE rowid = new.rowid;
END;

DROP VIEW IF EXISTS ParsedAgentString;
DROP VIEW IF EXISTS Parts;
DROP VIEW IF EXISTS ApplicationReleases;
DROP VIEW IF EXISTS SchemaVersions;
DROP VIEW IF EXISTS Versions;
CREATE VIEW Versions AS
SELECT Version.id AS version, name.value AS name,
 major.value ||
  COALESCE('.' || minor.value, '') ||
  COALESCE('.' || patch.value, '')
 AS value,
 major.value AS major,
 minor.value AS minor,
 patch.value AS patch
FROM Version
LEFT JOIN Word AS name ON name.id = Version.name
LEFT JOIN Word AS major ON major.id = Version.major
LEFT JOIN Word AS minor ON minor.id = Version.minor
LEFT JOIN Word AS patch ON patch.id = Version.patch;

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

CREATE VIEW ApplicationReleases AS
SELECT ApplicationRelease.id AS applicationRelease,
 ApplicationRelease.application,
 ApplicationRelease.release,
 Applications.name,
 Applications.goesBy,
 Applications.path AS applicationPath,
 Release.version AS versionId,
 Release.build AS buildId,
 Versions.value as versionName,
 Build.value as buildName
FROM ApplicationRelease
JOIN Applications ON Applications.application = ApplicationRelease.application
JOIN Release ON Release.id = ApplicationRelease.release
JOIN Versions ON Versions.version = Release.version
JOIN Word AS Build ON Build.id = Release.build;

CREATE VIEW Parts AS
SELECT Part.id AS part, Part.parent,
 I18NSentence.value AS name, Part.name AS nameId,
 CASE WHEN (Versions.name IS NOT NULL) THEN Versions.name ELSE '' END ||
 CASE WHEN (Versions.name IS NOT NULL) THEN ' ' ELSE '' END ||
 CASE WHEN (Versions.value IS NOT NULL) THEN Versions.value ELSE '' END AS version,
 Part.version AS versionId,
 Part.serial, Part.created
FROM Part
JOIN I18NSentence ON I18NSentence.id = Part.name
LEFT JOIN Versions ON Versions.version = Part.version;

CREATE VIEW ParsedAgentString AS
SELECT agentstring,
 deviceid, deviceversion, device, deviceversionname.value as deviceersionname,
 osid, OSRelease.version AS osversion, os, OSVersion.value AS osversionname,
 agentid, AgentVersion.version AS agentversion, agent, AgentVersion.value agentversionname
FROM ParsedAgentStringShort
JOIN ApplicationRelease AS OSApplicatonRelease ON OSApplicatonRelease.id = osapplicationrelease
JOIN ApplicationRelease AS AgentApplicationRelease ON AgentApplicationRelease.id = agentApplicationRelease
LEFT JOIN Versions AS deviceversionname ON deviceversionname.version = deviceversion
LEFT JOIN Release AS OSRelease ON OSRelease.id = OSApplicatonRelease.release
LEFT JOIN Versions AS OSVersion ON OSVersion.version = OSRelease.version
LEFT JOIN Release AS AgentRelease ON AgentRelease.id = AgentApplicationRelease.release
LEFT JOIN Versions AS AgentVersion ON AgentVersion.version = AgentRelease.version;
