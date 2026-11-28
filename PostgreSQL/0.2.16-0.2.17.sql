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

-- Names are the generated view's column list. CREATE OR REPLACE keeps those names.
CREATE OR REPLACE VIEW EdgeIndividuals (
 edge, startname, stopname, startindividual, startindividualname, starttype,
 stopindividual, stopindividualname, stoptype, hops, entry, direct, exit, start, stop
) AS
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

CREATE OR REPLACE FUNCTION Post (
 inDebitAccount varchar,
 inAmount numeric,
 inCreditAccount varchar
) RETURNS JournalEntryResult AS $$
BEGIN
 RETURN Post(inCreditAccount, inAmount, inDebitAccount, NULL);
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

-- SELECT SetSchemaVersion('Business', '0', '2', '17');

COMMIT;
