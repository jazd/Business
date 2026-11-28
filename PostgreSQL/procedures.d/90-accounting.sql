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

-- One open sentence for an entry. A different sentence stops the open row.
CREATE OR REPLACE FUNCTION SetEntryDescription (
 inEntry integer,
 inDescription varchar
) RETURNS integer AS $$
DECLARE
 sentence_id integer;
 description_id integer;
BEGIN
 IF inEntry IS NULL OR inDescription IS NULL OR btrim(inDescription) = '' THEN
  RETURN NULL;
 END IF;

 sentence_id := GetSentence(inDescription);

 PERFORM pg_advisory_lock(inEntry);
 BEGIN
  UPDATE EntryDescription
  SET stop = NOW()
  WHERE entry = inEntry
   AND description <> sentence_id
   AND stop IS NULL;

  INSERT INTO EntryDescription (entry, description)
  SELECT inEntry, sentence_id
  WHERE NOT EXISTS (
   SELECT 1
   FROM EntryDescription
   WHERE entry = inEntry
    AND description = sentence_id
    AND stop IS NULL
  );

  SELECT id INTO description_id
  FROM EntryDescription
  WHERE entry = inEntry
   AND description = sentence_id
   AND stop IS NULL
  LIMIT 1;

  PERFORM pg_advisory_unlock(inEntry);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(inEntry);
   RAISE;
 END;

 RETURN description_id;
END;
$$ LANGUAGE plpgsql;

-- One open reference of each type for an entry. value is the printed number.
-- A different value stops the open row of that type.
CREATE OR REPLACE FUNCTION SetEntryReference (
 inEntry integer,
 inType varchar,
 inValue varchar,
 inSequence smallint DEFAULT NULL
) RETURNS integer AS $$
DECLARE
 type_id integer;
 reference_id integer;
BEGIN
 IF inEntry IS NULL OR inType IS NULL OR btrim(inType) = ''
  OR inValue IS NULL OR btrim(inValue) = '' THEN
  RETURN NULL;
 END IF;

 type_id := GetIdentifier(inType);

 PERFORM pg_advisory_lock(inEntry);
 BEGIN
  UPDATE EntryReference
  SET stop = NOW()
  WHERE entry = inEntry
   AND type = type_id
   AND value <> inValue
   AND stop IS NULL;

  INSERT INTO EntryReference (entry, type, value, sequence)
  SELECT inEntry, type_id, inValue, inSequence
  WHERE NOT EXISTS (
   SELECT 1
   FROM EntryReference
   WHERE entry = inEntry
    AND type = type_id
    AND value = inValue
    AND stop IS NULL
  );

  SELECT id INTO reference_id
  FROM EntryReference
  WHERE entry = inEntry
   AND type = type_id
   AND value = inValue
   AND stop IS NULL
  LIMIT 1;

  IF inSequence IS NOT NULL THEN
   UPDATE EntryReference
   SET sequence = inSequence
   WHERE id = reference_id
    AND sequence IS DISTINCT FROM inSequence;
  END IF;

  PERFORM pg_advisory_unlock(inEntry);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(inEntry);
   RAISE;
 END;

 RETURN reference_id;
END;
$$ LANGUAGE plpgsql;

-- AccountName.account for a Post name.
-- An all-digit argument is the account id.
-- Any other argument matches Sentence.value in ClientCulture() first.
-- No row in that culture falls back to Sentence.value in any culture.
-- More than one account raises invalid_parameter_value. A missing name returns NULL.
CREATE OR REPLACE FUNCTION ResolveAccount (
 inName varchar
) RETURNS integer AS $$
DECLARE
 account_id integer;
 name_count integer;
BEGIN
 IF inName IS NULL OR btrim(inName) = '' THEN
  RETURN NULL;
 END IF;

 IF inName ~ '^[0-9]+$' THEN
  SELECT account
  INTO account_id
  FROM AccountName
  WHERE account = inName::integer;
  RETURN account_id;
 END IF;

 SELECT COUNT(DISTINCT AccountName.account)
 INTO name_count
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inName
  AND Sentence.culture = ClientCulture();

 IF name_count > 1 THEN
  RAISE EXCEPTION 'account name % matches more than one account', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 IF name_count = 1 THEN
  SELECT account
  INTO account_id
  FROM AccountName
  JOIN Sentence ON Sentence.id = AccountName.name
  WHERE Sentence.value = inName
   AND Sentence.culture = ClientCulture()
  ORDER BY AccountName.account
  LIMIT 1;
  RETURN account_id;
 END IF;

 SELECT COUNT(DISTINCT AccountName.account)
 INTO name_count
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inName;

 IF name_count > 1 THEN
  RAISE EXCEPTION 'account name % matches more than one account', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 SELECT account
 INTO account_id
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inName
 ORDER BY AccountName.account
 LIMIT 1;
 RETURN account_id;
END;
$$ LANGUAGE plpgsql;

-- Post a balanced General Journal entry.
-- A name matches Sentence.value in ClientCulture() first, then any culture.
-- More than one account with that name raises invalid_parameter_value and writes nothing.
-- An all-digit argument is AccountName.account.
-- With no account named Capital in the client culture, Capital matches Equity through es-MX.
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

 credit_account_id := ResolveAccount(inCreditAccount);
 debit_account_id := ResolveAccount(inDebitAccount);

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

-- Debit is the first account. Credit is the third. The date is omitted.
CREATE OR REPLACE FUNCTION Post (
 inDebitAccount varchar,
 inAmount numeric,
 inCreditAccount varchar
) RETURNS JournalEntryResult AS $$
BEGIN
 RETURN Post(inDebitAccount, inAmount, inCreditAccount, NULL);
END;
$$ LANGUAGE plpgsql;

-- Find or insert an account. The name is an en-US sentence.
-- type is an en-US word, or word id 70000 through 70007.
-- credit comes from the type. inContra keeps the type and flips credit.
-- The same name, type, and credit returns the existing id.
-- A different type or credit raises invalid_parameter_value and writes nothing.
-- A new id is at least 1000, or one past the current maximum when that is higher.
CREATE OR REPLACE FUNCTION GetAccount (
 inName varchar,
 inType varchar,
 inContra boolean
) RETURNS integer AS $$
DECLARE
 type_id integer;
 credit_flag boolean;
 normal_credit boolean;
 sentence_id integer;
 name_count integer;
 existing_id integer;
 existing_type integer;
 existing_credit boolean;
 new_id integer;
 seq text;
BEGIN
 IF inName IS NULL OR btrim(inName) = '' OR inType IS NULL OR btrim(inType) = '' THEN
  RAISE EXCEPTION 'account name and type are required'
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 IF inType ~ '^[0-9]+$' THEN
  type_id := inType::integer;
 ELSE
  SELECT id INTO type_id
  FROM Word
  WHERE culture = 1033
   AND UPPER(value) = UPPER(inType)
   AND id IN (70000, 70001, 70002, 70003, 70004, 70005, 70006, 70007)
  LIMIT 1;
 END IF;

 IF type_id IS NULL OR type_id NOT IN (70000, 70001, 70002, 70003, 70004, 70005, 70006, 70007) THEN
  RAISE EXCEPTION 'unknown account type %', inType
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 normal_credit := type_id IN (70001, 70002, 70003, 70006, 70007);
 IF COALESCE(inContra, false) THEN
  credit_flag := NOT normal_credit;
 ELSE
  credit_flag := normal_credit;
 END IF;

 sentence_id := GetSentence(inName);
 IF sentence_id IS NULL THEN
  RAISE EXCEPTION 'unknown sentence %', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 SELECT COUNT(*) INTO name_count
 FROM AccountName
 WHERE name = sentence_id;

 IF name_count > 1 THEN
  RAISE EXCEPTION 'account name % matches more than one account', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 IF name_count = 1 THEN
  SELECT account, type, credit
  INTO existing_id, existing_type, existing_credit
  FROM AccountName
  WHERE name = sentence_id;
  IF existing_type = type_id AND existing_credit IS NOT DISTINCT FROM credit_flag THEN
   RETURN existing_id;
  END IF;
  RAISE EXCEPTION 'account % already exists with a different type or credit', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 PERFORM pg_advisory_xact_lock(hashtext('business.AccountName'));
 SELECT CASE
  WHEN COALESCE(MAX(account), 0) + 1 > 1000 THEN COALESCE(MAX(account), 0) + 1
  ELSE 1000
 END
 INTO new_id
 FROM AccountName;

 INSERT INTO AccountName (account, name, type, credit)
 VALUES (new_id, sentence_id, type_id, credit_flag);

 seq := pg_get_serial_sequence('accountname', 'account');
 IF seq IS NOT NULL THEN
  PERFORM setval(seq::regclass, new_id, true);
 END IF;
 RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAccount (
 inName varchar,
 inType varchar
) RETURNS integer AS $$
BEGIN
 RETURN GetAccount(inName, inType, false);
END;
$$ LANGUAGE plpgsql;

-- One Sentence row for an existing id and culture.
-- An all-digit argument is the sentence id. Any other argument is the en-US text.
-- A second row for that id and culture is refused.
CREATE OR REPLACE FUNCTION SetSentenceCulture (
 inSentence varchar,
 inCulture varchar,
 inValue varchar
) RETURNS integer AS $$
DECLARE
 sentence_id integer;
 culture_code smallint;
BEGIN
 IF inSentence IS NULL OR btrim(inSentence) = ''
  OR inCulture IS NULL OR btrim(inCulture) = ''
  OR inValue IS NULL OR btrim(inValue) = '' THEN
  RAISE EXCEPTION 'sentence, culture, and text are required'
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 SELECT code INTO culture_code
 FROM Culture
 WHERE UPPER(name) = UPPER(inCulture);
 IF culture_code IS NULL THEN
  RAISE EXCEPTION 'unknown culture %', inCulture
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 IF inSentence ~ '^[0-9]+$' THEN
  sentence_id := inSentence::integer;
  IF NOT EXISTS (SELECT 1 FROM Sentence WHERE id = sentence_id) THEN
   RAISE EXCEPTION 'unknown sentence %', inSentence
    USING ERRCODE = 'invalid_parameter_value';
  END IF;
 ELSE
  sentence_id := GetSentence(inSentence);
  IF sentence_id IS NULL THEN
   RAISE EXCEPTION 'unknown sentence %', inSentence
    USING ERRCODE = 'invalid_parameter_value';
  END IF;
 END IF;

 IF EXISTS (
  SELECT 1 FROM Sentence
  WHERE id = sentence_id AND culture = culture_code
 ) THEN
  RAISE EXCEPTION 'sentence % already has a % row', sentence_id, inCulture
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 INSERT INTO Sentence (id, culture, value, length)
 VALUES (sentence_id, culture_code, inValue, LENGTH(inValue));
 RETURN sentence_id;
END;
$$ LANGUAGE plpgsql;

-- JournalName.journal for a book. A missing journal returns NULL.
CREATE OR REPLACE FUNCTION ResolveJournal (
 inName varchar
) RETURNS integer AS $$
DECLARE
 journal_id integer;
BEGIN
 IF inName IS NULL OR btrim(inName) = '' THEN
  RETURN NULL;
 END IF;
 IF inName ~ '^[0-9]+$' THEN
  SELECT journal INTO journal_id
  FROM JournalName
  WHERE journal = inName::integer;
  RETURN journal_id;
 END IF;
 SELECT journal INTO journal_id
 FROM JournalName
 JOIN Sentence ON Sentence.id = JournalName.name
 WHERE Sentence.value = inName
 ORDER BY JournalName.journal
 LIMIT 1;
 RETURN journal_id;
END;
$$ LANGUAGE plpgsql;

-- Find or insert a two-account book. One BookAccount row holds both sides.
-- The same journal and accounts return the existing id.
-- A different shape raises invalid_parameter_value and writes nothing.
CREATE OR REPLACE FUNCTION GetBook (
 inName varchar,
 inJournal varchar,
 inIncrease varchar,
 inDecrease varchar
) RETURNS integer AS $$
DECLARE
 journal_id integer;
 increase_id integer;
 decrease_id integer;
 sentence_id integer;
 expected text;
 actual text;
 book_id integer;
 new_id integer;
 seq text;
 found boolean := false;
BEGIN
 journal_id := ResolveJournal(inJournal);
 IF journal_id IS NULL THEN
  RAISE EXCEPTION 'unknown journal %', inJournal
   USING ERRCODE = 'invalid_parameter_value';
 END IF;
 increase_id := ResolveAccount(inIncrease);
 IF increase_id IS NULL THEN
  RAISE EXCEPTION 'unknown account %', inIncrease
   USING ERRCODE = 'invalid_parameter_value';
 END IF;
 decrease_id := ResolveAccount(inDecrease);
 IF decrease_id IS NULL THEN
  RAISE EXCEPTION 'unknown account %', inDecrease
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 sentence_id := GetSentence(inName);
 IF sentence_id IS NULL THEN
  RAISE EXCEPTION 'unknown sentence %', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 expected := increase_id::text || '|' || decrease_id::text || '|';

 FOR book_id, journal_id IN
  SELECT book, journal FROM BookName WHERE name = sentence_id ORDER BY book
 LOOP
  found := true;
  SELECT string_agg(line, E'\n' ORDER BY line)
  INTO actual
  FROM (
   SELECT COALESCE(increase::text, '') || '|' || COALESCE(decrease::text, '') || '|' ||
    CASE WHEN split IS NULL THEN '' ELSE (ROUND(split * 1000))::integer::text END AS line
   FROM BookAccount
   WHERE book = book_id AND stop IS NULL
  ) shape;
  IF journal_id = ResolveJournal(inJournal) AND actual IS NOT DISTINCT FROM expected THEN
   RETURN book_id;
  END IF;
 END LOOP;

 IF found THEN
  RAISE EXCEPTION 'book % already exists with different accounts', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 PERFORM pg_advisory_xact_lock(hashtext('business.BookName'));
 SELECT CASE
  WHEN COALESCE(MAX(book), 0) + 1 > 1000 THEN COALESCE(MAX(book), 0) + 1
  ELSE 1000
 END
 INTO new_id
 FROM BookName;

 INSERT INTO BookName (book, name, journal)
 VALUES (new_id, sentence_id, ResolveJournal(inJournal));
 INSERT INTO BookAccount (book, increase, decrease, split)
 VALUES (new_id, increase_id, decrease_id, NULL);

 seq := pg_get_serial_sequence('bookname', 'book');
 IF seq IS NOT NULL THEN
  PERFORM setval(seq::regclass, new_id, true);
 END IF;
 RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Find or insert a split book. Each array entry is one BookAccount row.
-- A NULL share is the 100% side and that side has one account.
-- Any other shares on a side add up to 1, or the helper writes nothing.
CREATE OR REPLACE FUNCTION GetBook (
 inName varchar,
 inJournal varchar,
 inIncrease varchar[],
 inIncreaseShare numeric[],
 inDecrease varchar[],
 inDecreaseShare numeric[]
) RETURNS integer AS $$
DECLARE
 journal_id integer;
 sentence_id integer;
 increase_ids integer[];
 decrease_ids integer[];
 i integer;
 n integer;
 total integer;
 any_null boolean;
 any_set boolean;
 lines text[];
 expected text;
 actual text;
 book_id integer;
 new_id integer;
 seq text;
 found boolean := false;
 share_key text;
BEGIN
 journal_id := ResolveJournal(inJournal);
 IF journal_id IS NULL THEN
  RAISE EXCEPTION 'unknown journal %', inJournal
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 n := COALESCE(array_length(inIncrease, 1), 0);
 IF n = 0 OR COALESCE(array_length(inDecrease, 1), 0) = 0 THEN
  RAISE EXCEPTION 'book needs an increase account and a decrease account'
   USING ERRCODE = 'invalid_parameter_value';
 END IF;
 IF COALESCE(array_length(inIncreaseShare, 1), 0) <> n
  OR COALESCE(array_length(inDecreaseShare, 1), 0) <> COALESCE(array_length(inDecrease, 1), 0) THEN
  RAISE EXCEPTION 'book shares must add up to 1'
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 any_null := false;
 any_set := false;
 total := 0;
 increase_ids := ARRAY[]::integer[];
 lines := ARRAY[]::text[];
 FOR i IN 1..n LOOP
  increase_ids := increase_ids || ResolveAccount(inIncrease[i]);
  IF increase_ids[i] IS NULL THEN
   RAISE EXCEPTION 'unknown account %', inIncrease[i]
    USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF inIncreaseShare[i] IS NULL THEN
   any_null := true;
   share_key := '';
  ELSE
   any_set := true;
   total := total + (ROUND(inIncreaseShare[i] * 1000))::integer;
   share_key := (ROUND(inIncreaseShare[i] * 1000))::integer::text;
  END IF;
  lines := lines || (increase_ids[i]::text || '||' || share_key);
 END LOOP;
 IF (any_null AND any_set) OR (any_null AND n <> 1) OR (any_set AND total <> 1000) THEN
  RAISE EXCEPTION 'book shares must add up to 1'
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 n := COALESCE(array_length(inDecrease, 1), 0);
 any_null := false;
 any_set := false;
 total := 0;
 decrease_ids := ARRAY[]::integer[];
 FOR i IN 1..n LOOP
  decrease_ids := decrease_ids || ResolveAccount(inDecrease[i]);
  IF decrease_ids[i] IS NULL THEN
   RAISE EXCEPTION 'unknown account %', inDecrease[i]
    USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF inDecreaseShare[i] IS NULL THEN
   any_null := true;
   share_key := '';
  ELSE
   any_set := true;
   total := total + (ROUND(inDecreaseShare[i] * 1000))::integer;
   share_key := (ROUND(inDecreaseShare[i] * 1000))::integer::text;
  END IF;
  lines := lines || ('|' || decrease_ids[i]::text || '|' || share_key);
 END LOOP;
 IF (any_null AND any_set) OR (any_null AND n <> 1) OR (any_set AND total <> 1000) THEN
  RAISE EXCEPTION 'book shares must add up to 1'
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 sentence_id := GetSentence(inName);
 IF sentence_id IS NULL THEN
  RAISE EXCEPTION 'unknown sentence %', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 SELECT string_agg(line, E'\n' ORDER BY line)
 INTO expected
 FROM unnest(lines) AS line;

 FOR book_id IN
  SELECT book FROM BookName WHERE name = sentence_id AND journal = journal_id ORDER BY book
 LOOP
  found := true;
  SELECT string_agg(line, E'\n' ORDER BY line)
  INTO actual
  FROM (
   SELECT COALESCE(increase::text, '') || '|' || COALESCE(decrease::text, '') || '|' ||
    CASE WHEN split IS NULL THEN '' ELSE (ROUND(split * 1000))::integer::text END AS line
   FROM BookAccount
   WHERE book = book_id AND stop IS NULL
  ) shape;
  IF actual IS NOT DISTINCT FROM expected THEN
   RETURN book_id;
  END IF;
 END LOOP;

 IF EXISTS (SELECT 1 FROM BookName WHERE name = sentence_id) THEN
  RAISE EXCEPTION 'book % already exists with different accounts', inName
   USING ERRCODE = 'invalid_parameter_value';
 END IF;

 PERFORM pg_advisory_xact_lock(hashtext('business.BookName'));
 SELECT CASE
  WHEN COALESCE(MAX(book), 0) + 1 > 1000 THEN COALESCE(MAX(book), 0) + 1
  ELSE 1000
 END
 INTO new_id
 FROM BookName;

 INSERT INTO BookName (book, name, journal)
 VALUES (new_id, sentence_id, journal_id);

 FOR i IN 1..COALESCE(array_length(increase_ids, 1), 0) LOOP
  INSERT INTO BookAccount (book, increase, decrease, split)
  VALUES (new_id, increase_ids[i], NULL, inIncreaseShare[i]);
 END LOOP;
 FOR i IN 1..COALESCE(array_length(decrease_ids, 1), 0) LOOP
  INSERT INTO BookAccount (book, increase, decrease, split)
  VALUES (new_id, NULL, decrease_ids[i], inDecreaseShare[i]);
 END LOOP;

 seq := pg_get_serial_sequence('bookname', 'book');
 IF seq IS NOT NULL THEN
  PERFORM setval(seq::regclass, new_id, true);
 END IF;
 RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- Inventory Movement
--
