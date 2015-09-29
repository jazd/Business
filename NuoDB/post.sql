-- No need for UPPER() calls in NuoDB
ALTER TABLE Culture ALTER COLUMN name COLLATE case_insensitive;
ALTER TABLE Word ALTER COLUMN value COLLATE case_insensitive;

DROP INDEX SENTENCE_CULTURE_VALUE;
ALTER TABLE Sentence ALTER COLUMN value COLLATE case_insensitive;
CREATE INDEX Sentance_culture_value ON Sentence(culture,value);

ALTER TABLE Country ALTER COLUMN code COLLATE case_insensitive;

DROP INDEX POSTAL_COUNTRY_CODE;
ALTER TABLE Postal ALTER COLUMN code COLLATE case_insensitive;
CREATE INDEX Postal_country_code ON Postal (country,code);

ALTER TABLE Path ALTER COLUMN host COLLATE case_insensitive;


-- Automatically created Sequences
ALTER SEQUENCE WORD$IDENTITY_SEQUENCE START WITH 2000000;
ALTER SEQUENCE SENTENCE$IDENTITY_SEQUENCE START WITH 2000000;
