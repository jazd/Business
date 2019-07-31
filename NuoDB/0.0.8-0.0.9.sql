-- NuoDB database schema version 0.0.8 to 0.0.9
-- Missing Unique Index on word
CREATE UNIQUE INDEX word_id_culture_value ON Word (id, culture, value);
-- Improper Unique Index on sentence and paragraph tables
DROP INDEX sentence_culture_value;
CREATE UNIQUE INDEX sentence_id_culture_value ON Sentence (id, culture, value);
DROP INDEX paragraph_culture_value;
CREATE UNIQUE INDEX paragraph_id_culture_value ON Paragraph (id, culture, value);
