-- I18N — Word / Sentence / Identifier (diagram: i18n)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
 word_id integer;
 lock_key bigint;
BEGIN
 IF word_value IS NOT NULL THEN
  -- Check if exists early
  SELECT id INTO word_id
  FROM Word
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Word.value) = UPPER(word_value)
   AND Word.culture = Culture.code
  LIMIT 1
  ;
  IF word_id IS NULL THEN
   lock_key := hashtext(word_value);
   -- Serialize concurrent inserts for the same text; always release the lock
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    SELECT id INTO word_id
    FROM Word
    JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
    WHERE UPPER(Word.value) = UPPER(word_value)
     AND Word.culture = Culture.code
    LIMIT 1;
    IF word_id IS NULL THEN
     INSERT INTO Word (value, culture)
     SELECT word_value, Culture.code
     FROM Culture
     WHERE UPPER(Culture.name) = UPPER(culture_name)
     ON CONFLICT (culture, (UPPER(value))) DO NOTHING;
     SELECT id INTO word_id
     FROM Word
     JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
     WHERE UPPER(Word.value) = UPPER(word_value)
      AND Word.culture = Culture.code
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN word_id;
END;
$$ LANGUAGE plpgsql;

-- Default to en-US
-- TODO: set a system wide default culture
CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT GetWord(word_value, 'en-US') AS id
 );
END;
$$ LANGUAGE plpgsql;

-- Identifiers are normally by convention en-US based names used in programming and protocols
-- Return the Id of an identifier
-- It is inserted if it does not already exist
-- Concurrent safe: re-check under lock + ON CONFLICT on word_value_null
CREATE OR REPLACE FUNCTION GetIdentifier (
 ident_value varchar
) RETURNS integer AS $$
DECLARE
 ident_id integer;
 lock_key bigint;
BEGIN
 IF ident_value IS NOT NULL THEN
  -- Check if exists early
  SELECT id INTO ident_id
  FROM Word
  WHERE UPPER(Word.value) = UPPER(ident_value)
   AND Word.culture IS NULL
  LIMIT 1;
  IF ident_id IS NULL THEN
   lock_key := hashtext(ident_value);
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    SELECT id INTO ident_id
    FROM Word
    WHERE UPPER(Word.value) = UPPER(ident_value)
     AND Word.culture IS NULL
    LIMIT 1;
    IF ident_id IS NULL THEN
     INSERT INTO Word (value, culture)
     VALUES (ident_value, NULL)
     ON CONFLICT ((UPPER(value))) WHERE culture IS NULL DO NOTHING;
     SELECT id INTO ident_id
     FROM Word
     WHERE UPPER(Word.value) = UPPER(ident_value)
      AND Word.culture IS NULL
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN ident_id;
END;
$$ LANGUAGE plpgsql;

-- Concurrent safe: re-check under advisory lock then insert-if-missing.
-- Note: cultured Sentence values are NOT globally unique per culture (translations
-- of different English phrases may share text). Do not use ON CONFLICT on value.
CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
 sentence_id integer;
 lock_key bigint;
BEGIN
 IF sentence_value IS NOT NULL THEN
  SELECT id INTO sentence_id
  FROM Sentence
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Sentence.value) = UPPER(sentence_value)
   AND Sentence.culture = Culture.code
  LIMIT 1;
  IF sentence_id IS NULL THEN
   lock_key := hashtext(sentence_value);
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    -- Re-check after lock (another session may have inserted)
    SELECT id INTO sentence_id
    FROM Sentence
    JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
    WHERE UPPER(Sentence.value) = UPPER(sentence_value)
     AND Sentence.culture = Culture.code
    LIMIT 1;
    IF sentence_id IS NULL THEN
     INSERT INTO Sentence (value, culture, length) (
      SELECT sentence_value, Culture.code, LENGTH(sentence_value)
      FROM Culture
      LEFT JOIN Sentence AS exists ON UPPER(exists.value) = UPPER(sentence_value)
       AND exists.culture = Culture.code
      WHERE UPPER(Culture.name) = UPPER(culture_name)
       AND exists.id IS NULL
      LIMIT 1
     );
     SELECT id INTO sentence_id
     FROM Sentence
     JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
     WHERE UPPER(Sentence.value) = UPPER(sentence_value)
      AND Sentence.culture = Culture.code
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN sentence_id;
END;
$$ LANGUAGE plpgsql;

-- Default to en-US
CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT GetSentence(sentence_value, 'en-US') AS id
 );
END;
$$ LANGUAGE plpgsql;


-- Concurrent safe: re-check under lock + ON CONFLICT on sentence_value_null
CREATE OR REPLACE FUNCTION GetIdentityPhrase (
 phrase_value varchar
) RETURNS integer AS $$
DECLARE
 ident_id integer;
 lock_key bigint;
BEGIN
 IF phrase_value IS NOT NULL THEN
  SELECT id INTO ident_id
  FROM Sentence
  WHERE UPPER(Sentence.value) = UPPER(phrase_value)
   AND Sentence.culture IS NULL
  LIMIT 1;
  IF ident_id IS NULL THEN
   lock_key := hashtext(phrase_value);
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    SELECT id INTO ident_id
    FROM Sentence
    WHERE UPPER(Sentence.value) = UPPER(phrase_value)
     AND Sentence.culture IS NULL
    LIMIT 1;
    IF ident_id IS NULL THEN
     INSERT INTO Sentence (value, culture)
     VALUES (phrase_value, NULL)
     ON CONFLICT ((UPPER(value))) WHERE culture IS NULL DO NOTHING;
     SELECT id INTO ident_id
     FROM Sentence
     WHERE UPPER(Sentence.value) = UPPER(phrase_value)
      AND Sentence.culture IS NULL
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN ident_id;
END;
$$ LANGUAGE plpgsql;

