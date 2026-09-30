-- =============================================================================
-- Business schema upgrade: 0.2.12 -> 0.2.13 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.13 is unreleased. Keep this file in sync with
-- develop (procedures.d, schema.xml, post.sql, Static seeds) so a database
-- installed at 0.2.12 can reach the same end state as a fresh 0.2.13 build.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.12 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.12-0.2.13.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.12 database)
-- ---------------------------------------------------------------------------
--
--  1) JournalReport: Total row sorts last (sortTotal). debit and credit stay numeric.
--  2) Book and Post round each new journal amount to 4 decimal places.
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '13') - last substantive step
--
-- =============================================================================

-- Total row sorts last. debit and credit stay numeric for existing CAST consumers.
CREATE OR REPLACE VIEW JournalReport ( journal, journalName, entry, account, type, ledger, ledgerName, debit, credit, rightside, created ) AS
SELECT journal,
 journalName,
 entry,
 account,
 type,
 ledger,
 ledgerName,
 debit,
 credit,
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
 SUM(debit) AS debit,
 SUM(credit) AS credit,
 NULL AS rightSide,
 NULL AS created,
 1 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
) AS JournalReportLines
ORDER BY sortTotal, entry, rightSide;

-- Book rounds each new journal amount to numeric(19,4). Rows already stored are not rewritten.
CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount numeric
) RETURNS JournalEntryResult AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 inAmount := round(inAmount, 4);

 SELECT book, journal
 INTO book_id, journal_id
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
 ;

 INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

 INSERT INTO JournalEntry (journal, book, entry,  account, credit, amount)
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  NOT increaseCredit AS credit,
  round((inAmount * increaseCreditIncrease) * split, 4) AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseCreditIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  increaseCredit AS credit,
  round((inAmount * increaseDebitIncrease) * split, 4) AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseDebitIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  NOT decreaseCredit AS credit,
  round((inAmount * decreaseCreditDecrease) * split, 4) AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseCreditDecrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  decreaseCredit AS credit,
  round((inAmount * decreaseDebitDecrease) * split, 4) AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseDebitDecrease IS NOT NULL
 ;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

-- Post rounds each new journal amount to numeric(19,4). The 3-argument Post calls this one.
CREATE OR REPLACE FUNCTION Post (
 inDebitAccount varchar,
 inAmount numeric,
 inCreditAccount varchar,
 inDateTime timestamp
) RETURNS JournalEntryResult AS $$
DECLARE
 journal_name varchar;
 journal_id integer;
 credit_account_id integer;
 debit_account_id integer;
 entry_id integer;
BEGIN
 inAmount := round(inAmount, 4);

 journal_name := 'General';

 IF inDateTime IS NULL THEN
  inDateTime := CAST(NOW() AS date);
 END IF;

 SELECT journal
 INTO journal_id
 FROM JournalName
 JOIN Sentence ON Sentence.id = JournalName.name
 WHERE Sentence.value = journal_name
 LIMIT 1
 ;

 SELECT account
 INTO credit_account_id
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inCreditAccount
 LIMIT 1
 ;

 SELECT account
 INTO debit_account_id
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inDebitAccount
 LIMIT 1
 ;

 IF journal_id IS NOT NULL AND credit_account_id IS NOT NULL AND debit_account_id IS NOT NULL THEN
  INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

  INSERT INTO JournalEntry (journal, entry, account, credit, amount, created)
  VALUES (journal_id, entry_id, credit_account_id, true, inAmount, inDateTime);
  INSERT INTO JournalEntry (journal, entry, account, credit, amount, created)
  VALUES (journal_id, entry_id, debit_account_id, false, inAmount, inDateTime);
 END IF;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

-- Mark schema upgraded to 0.2.13 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.13 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '13');
