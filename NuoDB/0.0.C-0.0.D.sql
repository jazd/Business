-- NuoDB database schema version 0.0.C to 0.0.D
-- Mark some NuoDB functions DETERMINISTIC
SET DELIMITER @
ALTER FUNCTION GetWord (
 word_value STRING,
 culture_name STRING
) RETURNS INTEGER DETERMINISTIC AS
 IF (word_value IS NOT NULL)
  INSERT INTO Word (value, culture) (
   SELECT word_value, Culture.code
   FROM Culture
   LEFT JOIN Word AS does_exist ON does_exist.value = word_value
    AND does_exist.culture = Culture.code
   WHERE Culture.name = culture_name
    AND does_exist.id IS NULL
  );
 END_IF;
 
 RETURN (
  SELECT id
  FROM Word
  JOIN Culture ON Culture.name = culture_name
  WHERE Word.value = word_value
   AND Word.culture = Culture.code
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Default to en-US
SET DELIMITER @
ALTER FUNCTION GetWord (
 word_value STRING
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
  SELECT GetWord(word_value, 'en-US') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
ALTER FUNCTION GetIdentifier (
 ident_value STRING
) RETURNS INTEGER DETERMINISTIC AS
 IF (ident_value IS NOT NULL)
  INSERT INTO Word (value, culture) (
   SELECT ident_value, NULL
   FROM Dual
   LEFT JOIN Word AS does_exist ON does_exist.value = ident_value
    AND does_exist.culture IS NULL
   WHERE does_exist.id IS NULL
  );
 END_IF;

 RETURN (
  SELECT id
  FROM Word
  WHERE Word.value = ident_value
   AND Word.culture IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
ALTER FUNCTION GetSentence (
 sentence_value STRING,
 culture_name STRING
) RETURNS INTEGER DETERMINISTIC AS
 IF (sentence_value IS NOT NULL)
  INSERT INTO Sentence (value, culture, length) (
   SELECT sentence_value, Culture.code, CHARACTER_LENGTH(sentence_value)
   FROM Culture
   LEFT JOIN Sentence AS does_exist ON does_exist.value = sentence_value
    AND does_exist.culture = Culture.code
   WHERE Culture.name = culture_name
    AND does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Sentence
  JOIN Culture ON Culture.name = culture_name
  WHERE Sentence.value = sentence_value
   AND Sentence.culture = Culture.code
 );
END_FUNCTION;
@
SET DELIMITER ;

-- Default to en-US
SET DELIMITER @
ALTER FUNCTION GetSentence (
 sentence_value DETERMINISTIC STRING
) RETURNS INTEGER AS
 RETURN (
  SELECT GetSentence(sentence_value, 'en-US') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
ALTER FUNCTION GetIdentityPhrase (
 phrase_value DETERMINISTIC STRING
) RETURNS INTEGER AS
 IF (phrase_value IS NOT NULL)
  INSERT INTO Sentence (value, culture, length) (
   SELECT phrase_value, NULL, CHARACTER_LENGTH(phrase_value)
   FROM Dual
   LEFT JOIN Sentence AS does_exist ON does_exist.value = phrase_value
    AND does_exist.culture IS NULL
   WHERE does_exist.id IS NULL
  );
 END_IF;
 RETURN (
  SELECT id
  FROM Sentence
  WHERE Sentence.value = phrase_value
   AND Sentence.culture IS NULL
 );
END_FUNCTION;
@
SET DELIMITER ;
