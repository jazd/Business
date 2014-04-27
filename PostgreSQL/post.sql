-- Do not allow duplicate words based on case
-- upper(value) is not allowed in an in-table constraint
CREATE UNIQUE INDEX word_value ON word(culture,upper(value));

-- Application or user insert on these tables should start at 10000
-- This leaves room for global constants that are guaranteed to exist
ALTER SEQUENCE word_id_seq RESTART WITH 10000;
ALTER SEQUENCE sentence_id_seq RESTART WITH 10000;
ALTER SEQUENCE person_id_seq RESTART WITH 10000;
ALTER SEQUENCE company_id_seq RESTART WITH 10000;
ALTER SEQUENCE individual_id_seq RESTART WITH 20000;
