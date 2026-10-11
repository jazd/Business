-- =============================================================================
-- Business schema upgrade: 0.2.14 -> 0.2.15 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.15 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.14.
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.14 (stop IS NULL)
--   * A downloaded 0.2.14 business.sqlite3 may still report 0.2.11.
--     upgrade-sqlite.sh treats that file as 0.2.14 when Entitlement and
--     SchemaVersions are already present.
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.14 0.2.15
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.14 shop database)
-- ---------------------------------------------------------------------------
--
--  1) EntitlementCurrent compares ends to CURRENT_TIMESTAMP. SQLite has no
--     ClientNow().
--  2) JournalReport and LedgerReport totals sum cent-rounded row amounts.
--     Stored JournalEntry.amount values stay at 4 decimal places.
--  3) ContentElement.name and ContentElement.type are integer columns.
--     Each is a GetIdentifier id (Word.culture is null). They are set
--     together, and only when word, sentence, and paragraph are all null.
--     Bash SetContentElement stores them. SetFormatAttribute and
--     StopFormatAttribute store name, value, and target with GetIdentifier.
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.15) when STAMP_VERSION=1.
-- Leave STAMP_VERSION unset until that release.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

ALTER TABLE ContentElement ADD COLUMN name integer;
ALTER TABLE ContentElement ADD COLUMN type integer;

DROP VIEW IF EXISTS EntitlementCurrent;
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
 AND (Entitlement.ends IS NULL OR Entitlement.ends > CURRENT_TIMESTAMP);

DROP VIEW IF EXISTS JournalReport;
CREATE VIEW JournalReport AS
SELECT journal,
 journalName,
 entry,
 account,
 type,
 ledger,
 ledgerName,
 CASE WHEN debit IS NULL THEN NULL ELSE printf('%.2f', debit) END AS debit,
 CASE WHEN credit IS NULL THEN NULL ELSE printf('%.2f', credit) END AS credit,
 rightSide,
 created
FROM (
SELECT journal,
 journalName,
 entry,
 accountName AS account,
 typeName AS type,
 ledger,
 ledgerName,
 debit,
 credit,
 rightSide,
 created,
 0 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
UNION ALL
SELECT NULL AS journal,
 NULL AS journalName,
 NULL AS entry,
 'Total' AS account,
 NULL AS type,
 MAX(ledger) AS ledger,
 MAX(ledgerName) AS ledgerName,
 COALESCE(SUM(ROUND(debit, 2)), 0) AS debit,
 COALESCE(SUM(ROUND(credit, 2)), 0) AS credit,
 NULL AS rightSide,
 NULL AS created,
 1 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
) AS JournalReportLines
ORDER BY sortTotal, entry, rightSide
LIMIT -1;

DROP VIEW IF EXISTS LedgerReport;
CREATE VIEW LedgerReport AS
SELECT ledger,
 sequence,
 ledgerName,
 accountName,
 typeName,
 CASE WHEN debit IS NULL THEN NULL ELSE printf('%.2f', debit) END AS debit,
 CASE WHEN credit IS NULL THEN NULL ELSE printf('%.2f', credit) END AS credit
FROM (
SELECT ledger,
 sequence,
 ledgerName,
 accountName,
 typeName,
 debit,
 credit,
 0 AS sortTotal
FROM LedgerBalance
UNION ALL
SELECT ledger,
 NULL AS sequence,
 ledgerName,
 'Total' AS accountName,
 NULL AS typeName,
 COALESCE(SUM(ROUND(debit, 2)), 0) AS debit,
 COALESCE(SUM(ROUND(credit, 2)), 0) AS credit,
 1 AS sortTotal
FROM LedgerBalance
GROUP BY ledger,
 ledgerName
) AS LedgerReportLines
ORDER BY ledger, sortTotal, sequence
LIMIT -1;
