-- =============================================================================
-- Business schema upgrade: 0.2.12 -> 0.2.13 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.13 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.12 so it reaches the same end state as a fresh
-- 0.2.13 business.sqlite3 template (DDL + seeds that Static would add).
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.12 (stop IS NULL)
--   * File backup taken (script can .backup before apply)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.12 0.2.13
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.12 shop database)
-- ---------------------------------------------------------------------------
--
--  1) JournalReport: two-decimal text amounts, no scientific notation; Total row last
--  2) No column change. Bash Book and Post round each new journal amount to 4 decimal places.
--  3) Accounts, Ledgers, LedgerBalance, and LedgerReport.
--     LedgerReport sums journal lines onto the chart account of the same type
--     (Asset, Liability, Income, Expenses). Amounts are two-decimal text. Total is last.
--  4) Bash Book and BookBalance write created as YYYY-MM-DD on each new journal line.
--     An omitted date is today in the given time zone, or the local zone when the
--     time zone is omitted. An explicit date is stored as given.
--     Rows already stored are not rewritten. No column change.
--
-- SQLite does not enforce varchar(n). Width-only ALTERs are no-ops here.
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.13) when STAMP_VERSION=1.
-- Leave STAMP_VERSION unset until that release.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

-- Amounts are text with two decimal places. Total is the last row.
-- SQLite keeps ORDER BY on a view only when LIMIT is present; LIMIT -1 returns every row.
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
 COALESCE(SUM(debit), 0) AS debit,
 COALESCE(SUM(credit), 0) AS credit,
 NULL AS rightSide,
 NULL AS created,
 1 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
) AS JournalReportLines
ORDER BY sortTotal, entry, rightSide
LIMIT -1;

-- Chart accounts and the ledger that lists them. LedgerReport sums open
-- journal lines (posted IS NULL) onto the chart account of the same type.
-- Amounts on LedgerReport are text with two decimal places. Total is last.
-- SQLite keeps ORDER BY on a view only when LIMIT is present; LIMIT -1 returns every row.
DROP VIEW IF EXISTS LedgerReport;
DROP VIEW IF EXISTS LedgerBalance;
DROP VIEW IF EXISTS Ledgers;
DROP VIEW IF EXISTS Accounts;

CREATE VIEW Accounts AS
SELECT AccountName.account,
 I18NSentence.value AS name,
 AccountName.type,
 TypeName.value AS typeName,
 IndividualAccount.individual,
 COALESCE(People.fullname, Entities.name) AS individualName,
 IndividualAccount.type AS individualAccountType,
 IndividualAccountType.value AS individualAccountTypeName,
 AccountName.credit,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitIncrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitDecrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditIncrease,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditDecrease
FROM AccountName
JOIN I18NSentence ON I18NSentence.id = AccountName.name
JOIN I18NWord AS TypeName ON TypeName.id = AccountName.type
LEFT JOIN IndividualAccount ON IndividualAccount.account = AccountName.account
 AND IndividualAccount.stop IS NULL
LEFT JOIN People ON People.individual = IndividualAccount.individual
LEFT JOIN Entities ON Entities.individual = IndividualAccount.individual
LEFT JOIN I18NWord AS IndividualAccountType ON IndividualAccountType.id = IndividualAccount.type;

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
JOIN Accounts ON Accounts.account = LedgerAccount.account;

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
 COALESCE(SUM(debit), 0) AS debit,
 COALESCE(SUM(credit), 0) AS credit,
 1 AS sortTotal
FROM LedgerBalance
GROUP BY ledger,
 ledgerName
) AS LedgerReportLines
ORDER BY ledger, sortTotal, sequence
LIMIT -1;
