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
--  5) Account 6 name points at sentence 224 (Fixed Assets). Sentence 78 stays
--     on account 103 and on the Equipment book. JournalEntry rows are not rewritten.
--     Books Capital, Card Sale, and Hosting are inserted when those rows are missing.
--     Bash Post exits non-zero when a name matches more than one account.
--     An all-digit argument is an account id.
--  6) InvoiceLineDetail.description is the part name, plus the part description
--     when PartDescription has one. It is not the part version.
--     Bash SetSchedule inserts a Schedule band and does not update an existing band.
--     Bash SetPrice inserts AssemblyIndividualJobPrice. That price is the quote unit price.
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

-- Chart account 6 is Fixed Assets (sentence 224). Sentence 78 stays on account 103
-- and on the Equipment book. Sentence 225 is the Capital book only, not an AccountName.
-- Sentence 226 is the Card Sale book only. Sentence 227 is the Hosting book and
-- expense account 109. JournalEntry rows are not rewritten.
INSERT INTO Sentence (id,culture,value,length) SELECT 224,1033,'Fixed Assets',12 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id = 224 AND culture = 1033);
INSERT INTO Sentence (id,culture,value,length) SELECT 225,1033,'Capital',7 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id = 225 AND culture = 1033);
INSERT INTO Sentence (id,culture,value,length) SELECT 226,1033,'Card Sale',9 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id = 226 AND culture = 1033);
INSERT INTO Sentence (id,culture,value,length) SELECT 227,1033,'Hosting',7 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id = 227 AND culture = 1033);

UPDATE AccountName SET name = 224 WHERE account = 6 AND name = 78;

INSERT INTO AccountName (account, name, type, credit) SELECT 109, 227, 70004, false WHERE NOT EXISTS (SELECT 1 FROM AccountName WHERE account = 109);

INSERT INTO BookName (book, name, journal) SELECT 24, 225, 4 WHERE NOT EXISTS (SELECT 1 FROM BookName WHERE book = 24);
INSERT INTO BookName (book, name, journal) SELECT 25, 226, 2 WHERE NOT EXISTS (SELECT 1 FROM BookName WHERE book = 25);
INSERT INTO BookName (book, name, journal) SELECT 26, 227, 6 WHERE NOT EXISTS (SELECT 1 FROM BookName WHERE book = 26);

INSERT INTO BookAccount (book, increase, decrease)
SELECT 24, 100, 5
WHERE NOT EXISTS (
 SELECT 1 FROM BookAccount WHERE book = 24 AND increase = 100 AND decrease = 5 AND stop IS NULL
);
INSERT INTO BookAccount (book, increase, decrease)
SELECT 25, 110, 102
WHERE NOT EXISTS (
 SELECT 1 FROM BookAccount WHERE book = 25 AND increase = 110 AND decrease = 102 AND stop IS NULL
);
INSERT INTO BookAccount (book, increase, decrease)
SELECT 26, 109, 100
WHERE NOT EXISTS (
 SELECT 1 FROM BookAccount WHERE book = 26 AND increase = 109 AND decrease = 100 AND stop IS NULL
);

-- description is the part name, plus the part description when PartDescription has one.
DROP VIEW IF EXISTS InvoiceLineDetail;
CREATE VIEW InvoiceLineDetail AS
SELECT
 li.bill,
 li.line,
 li.item AS product,
 CASE
  WHEN (
   SELECT para.value
   FROM PartDescription pd
   JOIN I18NParagraph AS para ON para.id = pd.description
   WHERE pd.part = li.part
    AND pd.stop IS NULL
    AND para.value IS NOT NULL
    AND para.value != ''
   ORDER BY pd.created DESC
   LIMIT 1
  ) IS NULL THEN li.item
  ELSE li.item || ' - ' || (
   SELECT para.value
   FROM PartDescription pd
   JOIN I18NParagraph AS para ON para.id = pd.description
   WHERE pd.part = li.part
    AND pd.stop IS NULL
    AND para.value IS NOT NULL
    AND para.value != ''
   ORDER BY pd.created DESC
   LIMIT 1
  )
 END AS description,
 COALESCE(li.count, 1) AS qty,
 li.unitPrice AS rate,
 li.currentUnitPrice,
 li.totalPrice AS amount,
 li.outstanding,
 li.typeName,
 li.supplierName,
 li.consigneeName
FROM LineItems li;
