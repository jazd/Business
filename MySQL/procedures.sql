-- The MIT License (MIT) Copyright (c) 2014-2020 Stephen A Jazdzewski
-- MySQL Functions and Procedures
--
-- MySQL Does not support FUNCTION overloading :-(

USE Business;

DROP FUNCTION IF EXISTS GetSentenceCulture;
DELIMITER $$
CREATE FUNCTION GetSentenceCulture (
 sentence_value varchar(256),
 culture_name varchar(9)
) RETURNS Integer DETERMINISTIC
BEGIN
 IF sentence_value IS NOT NULL THEN
  INSERT INTO Sentence (value, culture, length) (
   SELECT sentence_value, Culture.code AS culture, LENGTH(sentence_value)
   FROM Culture
   LEFT JOIN Sentence AS does_exists ON UPPER(does_exists.value) = UPPER(sentence_value)
    AND does_exists.culture = Culture.code
   WHERE UPPER(Culture.name) = UPPER(culture_name)
    AND does_exists.id IS NULL
   LIMIT 1
  );
 END IF;
 RETURN (
  SELECT id
  FROM Sentence
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Sentence.value) = UPPER(sentence_value)
   AND Sentence.culture = Culture.code
  LIMIT 1
 );
END $$
DELIMITER ;

DROP FUNCTION IF EXISTS GetSentence;
DELIMITER $$
CREATE FUNCTION GetSentence (
 sentence_value varchar(256)
) RETURNS Integer DETERMINISTIC
BEGIN
 RETURN (
  SELECT GetSentenceCulture(sentence_value, 'en-US') AS id
 );
END $$
DELIMITER ;
