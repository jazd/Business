-- Double-entry Book / Post (diagram: accounting)
-- Assembled in lexicographic order of this directory; see README.md

-- Drop functions thas use JournalEntryResult
DROP FUNCTION IF EXISTS Book(varchar, float);
DROP FUNCTION IF EXISTS Book(varchar, numeric);
DROP FUNCTION IF EXISTS Post(varchar, float, varchar);
DROP FUNCTION IF EXISTS Post(varchar, numeric, varchar);
DROP FUNCTION IF EXISTS Post(varchar, float, varchar, timestamp);
DROP FUNCTION IF EXISTS Post(varchar, numeric, varchar, timestamp);
--
DROP TYPE IF EXISTS JournalEntryResult CASCADE;
CREATE TYPE JournalEntryResult AS (
 journal INTEGER,
 entry INTEGER
);

--
-- Book single amounts into double entry Journal.
-- Book(varchar, numeric) and Book(varchar, numeric, date) call this function.
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

-- Post a balanced General Journal entry
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
 -- numeric(19,4). New amounts are rounded here. Rows already stored are not rewritten.
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
  -- Get a new unique entry_id
  INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

  -- Balanced entries
  INSERT INTO JournalEntry (journal, entry, account, credit, amount, created)
  VALUES (journal_id, entry_id, credit_account_id, true, inAmount, inDateTime);
  INSERT INTO JournalEntry (journal, entry, account, credit, amount, created)
  VALUES (journal_id, entry_id, debit_account_id, false, inAmount, inDateTime);
 END IF;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Post (
 inDebitAccount varchar,
 inAmount numeric,
 inCreditAccount varchar
) RETURNS JournalEntryResult AS $$
BEGIN
 RETURN Post(inCreditAccount, inAmount, inDebitAccount, NULL);
END;
$$ LANGUAGE plpgsql;


-- Inventory Movement
--
