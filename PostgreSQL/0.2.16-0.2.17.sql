-- =============================================================================
-- Business schema upgrade: 0.2.16 -> 0.2.17 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.17 is unreleased. Apply to a database
-- installed at 0.2.16.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Active SchemaVersion is Business 0.2.16 (stop IS NULL)
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.16-0.2.17.sql
--
-- The script is one transaction. A failed statement rolls the change back.
--
-- Version stamp stays commented until 0.2.17 is released.
--
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

SET search_path TO business, public;

DO $$
BEGIN
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
   AND patch.value = '16'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.16';
 END IF;
END $$;

CREATE OR REPLACE VIEW Ledgers AS
SELECT LedgerName.ledger,
 I18NSentence.value AS name,
 LedgerAccount.sequence,
 Accounts.account,
 Accounts.name AS accountName,
 Accounts.type,
 Accounts.typeName,
 Accounts.credit,
 Accounts.debitIncrease,
 Accounts.debitDecrease,
 Accounts.creditIncrease,
 Accounts.creditDecrease
FROM LedgerName
JOIN I18NSentence ON I18NSentence.id = LedgerName.name
JOIN LedgerAccount ON LedgerAccount.ledger = LedgerName.ledger
 AND LedgerAccount.stop IS NULL
JOIN Accounts ON Accounts.account = LedgerAccount.account;

CREATE OR REPLACE VIEW Books AS
SELECT BookName.book,
 I18NSentence.value AS name,
 BookName.journal,
 Journals.name AS journalName,
 COALESCE(BookAccount.split, 1) AS split,
 BookAccount.increase,
 Increase.name AS increaseName,
 Increase.type AS increaseType,
 Increase.credit AS increaseCredit,
 Increase.debitIncrease AS increaseDebitIncrease,
 Increase.debitDecrease AS increaseDebitDecrease,
 Increase.creditIncrease AS increaseCreditIncrease,
 Increase.creditDecrease AS increaseCreditDecrease,
 BookAccount.decrease,
 Decrease.name AS decreaseName,
 Decrease.type AS decreaseType,
 Decrease.credit AS decreaseCredit,
 Decrease.debitIncrease AS decreaseDebitIncrease,
 Decrease.debitDecrease AS decreaseDebitDecrease,
 Decrease.creditIncrease AS decreaseCreditIncrease,
 Decrease.creditDecrease AS decreaseCreditDecrease
FROM BookName
JOIN I18NSentence ON I18NSentence.id = BookName.name
JOIN Journals ON Journals.journal = BookName.journal
JOIN BookAccount ON BookAccount.book = BookName.book
 AND BookAccount.stop IS NULL
LEFT JOIN Accounts AS Increase ON Increase.account = BookAccount.increase
LEFT JOIN Accounts AS Decrease ON Decrease.account = BookAccount.decrease;

CREATE OR REPLACE VIEW Assemblies AS
SELECT DISTINCT AssemblyPart.assembly, Parent.name AS parentName,
 Assemblies.name,
 Assemblies.versionId AS version, Assemblies.version AS versionName, Assemblies.serial
FROM AssemblyPart
JOIN Parts AS Assemblies ON Assemblies.part = AssemblyPart.assembly
JOIN Parts AS Parent ON Parent.part = Assemblies.parent
WHERE AssemblyPart.stop IS NULL;

CREATE OR REPLACE VIEW EdgeIndividuals AS
SELECT Edge.id AS edge,
 StartVertexNameString.value AS startName,
 StopVertexNameString.value AS stopName,
 StartIndividualVertex.individual AS startIndividual,
 StartType.value AS startType,
 COALESCE(StartPeople.fullname, StartEntities.name) AS startIndividualName,
 StopIndividualVertex.individual AS stopIndividual,
 COALESCE(StopPeople.fullname, StopEntities.name) AS stopIndividualName,
 StopType.value AS stopType,
 hops, entry, direct, exit, start, Edge.stop
FROM Edge
JOIN VertexName AS StartVertexName ON StartVertexName.vertex = Edge.start
JOIN VertexName AS StopVertexName ON StopVertexName.vertex = Edge.stop
LEFT JOIN I18NSentence AS StartVertexNameString ON StartVertexNameString.id = StartVertexName.name
LEFT JOIN I18NSentence AS StopVertexNameString ON StopVertexNameString.id = StopVertexName.name
LEFT JOIN IndividualVertex AS StartIndividualVertex ON StartIndividualVertex.vertex = Edge.start
 AND StartIndividualVertex.stop IS NULL
LEFT JOIN People AS StartPeople ON StartPeople.individual = StartIndividualVertex.individual
LEFT JOIN Entities AS StartEntities ON StartEntities.individual = StartIndividualVertex.individual
LEFT JOIN Word AS StartType ON StartType.id = StartIndividualVertex.type
 AND StartType.culture IS NULL
LEFT JOIN IndividualVertex AS StopIndividualVertex ON StopIndividualVertex.vertex = Edge.stop
 AND StopIndividualVertex.stop IS NULL
LEFT JOIN People AS StopPeople ON StopPeople.individual = StopIndividualVertex.individual
LEFT JOIN Entities AS StopEntities ON StopEntities.individual = StopIndividualVertex.individual
LEFT JOIN Word AS StopType ON StopType.id = StopIndividualVertex.type
 AND StopType.culture IS NULL;

CREATE OR REPLACE VIEW Certificates AS
SELECT Certificate.id,
 Type.value AS type,
 (CACertificate.ca IS NOT NULL) AS isca,
 CAPolicy.ca,
 CA.parent,
 start,
 Certificate.days,
 Start + Certificate.days * INTERVAL '1 day' AS stop,
 cn,
 Certificate.serial
FROM Certificate
JOIN I18NWord AS Type ON Type.id = Certificate.type
JOIN CAPolicy ON CAPolicy.id = Certificate.CAPolicy
JOIN CA ON CA.id = CAPolicy.ca
LEFT JOIN CACertificate ON CACertificate.certificate = Certificate.id
 AND CACertificate.stop IS NULL;

-- SELECT SetSchemaVersion('Business', '0', '2', '17');

COMMIT;
