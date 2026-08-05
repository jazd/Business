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
-- Book single amounts into double entry Journal
CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount numeric
) RETURNS JournalEntryResult AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 -- Pickup book and journal to use
 SELECT book, journal
 INTO book_id, journal_id
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
 ;

 -- Get a new unique entry_id
 INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

 INSERT INTO JournalEntry (journal, book, entry,  account, credit, amount)
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  NOT increaseCredit AS credit,
  (inAmount * increaseCreditIncrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseCreditIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  increaseCredit AS credit,
  (inAmount * increaseDebitIncrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseDebitIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  NOT decreaseCredit AS credit,
  (inAmount * decreaseCreditDecrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseCreditDecrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  decreaseCredit AS credit,
  (inAmount * decreaseDebitDecrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseDebitDecrease IS NOT NULL
 ;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

-- Book and return new balances
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

 SELECT * INTO journal_id, entry_id FROM Book(inBook, inAmount);

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
