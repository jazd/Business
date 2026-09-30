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
--  3) Book and BookBalance store a civil date on each new journal line.
--     The date and time zone follow the amount. Book(varchar, numeric) remains.
--     An omitted date is today in the time zone, or the session TimeZone when
--     the time zone is omitted. An explicit date is stored as given.
--     Rows already stored are not rewritten.
--  4) Account 6 name points at sentence 224 (Fixed Assets). Sentence 78 stays
--     on account 103 and on the Equipment book. JournalEntry rows are not rewritten.
--     Books Capital, Card Sale, and Hosting are inserted when those rows are missing.
--     Post raises invalid_parameter_value when a name matches more than one account.
--     An all-digit argument is an account id.
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

-- Book(varchar, numeric) and Book(varchar, numeric, date) call the 4-argument function.
-- A new line stores created as a civil date and no time. An omitted date is
-- today in inTimeZone, or in the session TimeZone when inTimeZone is omitted.
-- An explicit date is stored as given. Rows already stored are not rewritten.
CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount numeric,
 inDate date,
 inTimeZone varchar
) RETURNS JournalEntryResult AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
 entry_date date;
BEGIN
 -- numeric(19,4). New amounts are rounded here. Rows already stored are not rewritten.
 inAmount := round(inAmount, 4);

 IF inDate IS NOT NULL THEN
  entry_date := inDate;
 ELSIF inTimeZone IS NULL OR btrim(inTimeZone) = '' THEN
  entry_date := CAST(NOW() AS date);
 ELSE
  entry_date := CAST((NOW() AT TIME ZONE inTimeZone) AS date);
 END IF;

 -- Pickup book and journal to use
 SELECT book, journal
 INTO book_id, journal_id
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
 ;

 -- Get a new unique entry_id
 INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

 INSERT INTO JournalEntry (journal, book, entry, account, credit, amount, created)
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  NOT increaseCredit AS credit,
  round((inAmount * increaseCreditIncrease) * split, 4) AS amount,
  entry_date
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseCreditIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  increaseCredit AS credit,
  round((inAmount * increaseDebitIncrease) * split, 4) AS amount,
  entry_date
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseDebitIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  NOT decreaseCredit AS credit,
  round((inAmount * decreaseCreditDecrease) * split, 4) AS amount,
  entry_date
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseCreditDecrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  decreaseCredit AS credit,
  round((inAmount * decreaseDebitDecrease) * split, 4) AS amount,
  entry_date
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseDebitDecrease IS NOT NULL
 ;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount numeric,
 inDate date
) RETURNS JournalEntryResult AS $$
BEGIN
 RETURN Book(inBook, inAmount, inDate, NULL::varchar);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount numeric
) RETURNS JournalEntryResult AS $$
BEGIN
 RETURN Book(inBook, inAmount, NULL::date, NULL::varchar);
END;
$$ LANGUAGE plpgsql;

-- Book and return new balances. Date and time zone follow the amount and
-- are passed to Book. BookBalance(varchar, numeric) calls this function.
CREATE OR REPLACE FUNCTION BookBalance (
 inBook varchar,
 inAmount numeric,
 inDate date,
 inTimeZone varchar
) RETURNS TABLE (
 book integer,
 entry integer,
 account integer,
 nameId integer,
 name varchar,
 rightside boolean,
 type integer,
 typeName varchar,
 debit numeric,
 credit numeric
) AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 book_id := (
  SELECT BookName.book
  FROM BookName
  WHERE BookName.name = GetSentence(inBook)
  LIMIT 1
 );

 -- Book rounds inAmount to 4 decimal places before insert and stores a civil date.
 SELECT * INTO journal_id, entry_id FROM Book(inBook, inAmount, inDate, inTimeZone);

 RETURN QUERY
  SELECT book_id AS book,
   entry_id AS entry,
   Transactions.account,
   AccountName.name AS nameId,
   Sentence.value AS name,
   AccountName.credit AS rightside,
   AccountName.type,
   Word.value AS typeName,
   SUM(Transactions.debit) AS debit,
   SUM(transactions.credit) AS credit
  FROM (
   SELECT JournalEntry.account,
    CASE WHEN NOT JournalEntry.credit THEN
     JournalEntry.amount
    END AS debit,
    CASE WHEN JournalEntry.credit THEN
     JournalEntry.amount
    END AS credit
   FROM JournalEntry
   WHERE JournalEntry.account IN (
    SELECT DISTINCT JournalEntry.account
    FROM JournalEntry
    WHERE JournalEntry.entry = entry_id
     AND posted IS NULL
   ) AND JournalEntry.posted IS NULL
  ) AS Transactions
  JOIN AccountName ON AccountName.account = Transactions.account
  JOIN Word ON Word.id = AccountName.type
   AND Word.culture = 1033
  JOIN Sentence ON Sentence.id = AccountName.name
   AND Sentence.culture = 1033
  GROUP BY Transactions.account, AccountName.name, AccountName.credit, AccountName.type, Word.value, Sentence.value
  ;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION BookBalance (
 inBook varchar,
 inAmount numeric,
 inDate date
) RETURNS TABLE (
 book integer,
 entry integer,
 account integer,
 nameId integer,
 name varchar,
 rightside boolean,
 type integer,
 typeName varchar,
 debit numeric,
 credit numeric
) AS $$
BEGIN
 RETURN QUERY
  SELECT * FROM BookBalance(inBook, inAmount, inDate, NULL::varchar);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION BookBalance (
 inBook varchar,
 inAmount numeric
) RETURNS TABLE (
 book integer,
 entry integer,
 account integer,
 nameId integer,
 name varchar,
 rightside boolean,
 type integer,
 typeName varchar,
 debit numeric,
 credit numeric
) AS $$
BEGIN
 RETURN QUERY
  SELECT * FROM BookBalance(inBook, inAmount, NULL::date, NULL::varchar);
END;
$$ LANGUAGE plpgsql;

-- Post rounds each new journal amount to numeric(19,4). The 3-argument Post calls this one.
-- A name matches Sentence.value in any culture.
-- More than one account with that name raises invalid_parameter_value and writes nothing.
-- An all-digit argument is AccountName.account.
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
 credit_name_count integer;
 debit_name_count integer;
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

 IF inCreditAccount ~ '^[0-9]+$' THEN
  SELECT account
  INTO credit_account_id
  FROM AccountName
  WHERE account = inCreditAccount::integer;
 ELSE
  SELECT COUNT(DISTINCT AccountName.account)
  INTO credit_name_count
  FROM AccountName
  JOIN Sentence ON Sentence.id = AccountName.name
  WHERE Sentence.value = inCreditAccount;

  IF credit_name_count > 1 THEN
   RAISE EXCEPTION 'account name % matches more than one account', inCreditAccount
    USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT account
  INTO credit_account_id
  FROM AccountName
  JOIN Sentence ON Sentence.id = AccountName.name
  WHERE Sentence.value = inCreditAccount
  LIMIT 1;
 END IF;

 IF inDebitAccount ~ '^[0-9]+$' THEN
  SELECT account
  INTO debit_account_id
  FROM AccountName
  WHERE account = inDebitAccount::integer;
 ELSE
  SELECT COUNT(DISTINCT AccountName.account)
  INTO debit_name_count
  FROM AccountName
  JOIN Sentence ON Sentence.id = AccountName.name
  WHERE Sentence.value = inDebitAccount;

  IF debit_name_count > 1 THEN
   RAISE EXCEPTION 'account name % matches more than one account', inDebitAccount
    USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT account
  INTO debit_account_id
  FROM AccountName
  JOIN Sentence ON Sentence.id = AccountName.name
  WHERE Sentence.value = inDebitAccount
  LIMIT 1;
 END IF;

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

-- Mark schema upgraded to 0.2.13 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.13 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '13');
