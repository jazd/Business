-- =============================================================================
-- Business schema upgrade: 0.2.16 -> 0.2.17 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.17 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.16.
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.16 (stop IS NULL)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.16 0.2.17
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.17) when STAMP_VERSION=1.
-- Leave STAMP_VERSION unset until that release.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

DROP VIEW IF EXISTS LedgerBalance;
DROP VIEW IF EXISTS Books;
DROP VIEW IF EXISTS Ledgers;
DROP VIEW IF EXISTS Assemblies;
DROP VIEW IF EXISTS EdgeIndividuals;

CREATE VIEW Ledgers AS
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

CREATE VIEW Books AS
SELECT BookName.book,
 I18NSentence.value AS name,
 BookName.journal,
 Journals.name AS journalName,
 COALESCE(BookAccount.split, 1) AS split,
 BookAccount.increase,
 Increase.name AS increaseName,
 Increase.type AS increaseType,
 Increase.credit AS increaseCredit,
 Increase.debitIncrease  AS increaseDebitIncrease,
 Increase.debitDecrease  AS increaseDebitDecrease,
 Increase.creditIncrease AS increaseCreditIncrease,
 Increase.creditDecrease  AS increaseCreditDecrease,
 BookAccount.decrease,
 Decrease.name AS decreaseName,
 Decrease.type AS decreaseType,
 Decrease.credit AS decreaseCredit,
 Decrease.debitIncrease  AS decreaseDebitIncrease,
 Decrease.debitDecrease  AS decreaseDebitDecrease,
 Decrease.creditIncrease AS decreaseCreditIncrease,
 Decrease.creditDecrease AS decreaseCreditDecrease
FROM BookName
JOIN I18NSentence ON I18NSentence.id = BookName.name
JOIN Journals ON Journals.journal = BookName.journal
JOIN BookAccount ON BookAccount.book = BookName.book
 AND BookAccount.stop IS NULL
LEFT JOIN Accounts AS Increase ON Increase.account = BookAccount.increase
LEFT JOIN Accounts AS Decrease  ON Decrease.account  = BookAccount.decrease;

CREATE VIEW LedgerBalance AS
SELECT Ledgers.ledger,
 Ledgers.name AS ledgerName,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName,
 SUM(JournalEntries.debit) AS debit,
 SUM(JournalEntries.credit) AS credit
FROM JournalEntries
JOIN Ledgers ON Ledgers.ledger = JournalEntries.ledger
 AND Ledgers.type = JournalEntries.type
WHERE JournalEntries.posted IS NULL
GROUP BY Ledgers.ledger,
 Ledgers.name,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName;

CREATE VIEW Assemblies AS
SELECT DISTINCT AssemblyPart.assembly, Parent.name AS parentName,
 Assemblies.name,
 Assemblies.versionId AS version, Assemblies.version as VersionName, Assemblies.serial
FROM AssemblyPart
JOIN Parts AS Assemblies ON Assemblies.part = AssemblyPart.assembly
JOIN Parts AS Parent ON Parent.part = Assemblies.parent
WHERE AssemblyPart.stop IS NULL;

CREATE VIEW EdgeIndividuals AS
SELECT Edge.id AS edge,
 StartVertexNameString.value AS startName,
 StopVertexNameString.value AS stopName,
 StartIndividualVertex.individual AS startIndividual,
 StartType.value AS startType,
 COALESCE(StartPeople.fullname, StartEntities.name) AS startIndividualName,
 StopIndividualVertex.individual AS stopIndividual,
 COALESCE(StopPeople.fullname, StopEntities.name) AS stopIndividualName,
 StopType.value AS stopType,
 hops,
 entry,
 direct,
 exit,
 start,
 Edge.stop
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
