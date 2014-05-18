-- Do not allow duplicate words based on case
-- upper(value) is not allowed in an in-table constraint
CREATE UNIQUE INDEX word_value ON word(culture,upper(value));

-- Do not allow duplicate People table entries with a single NULL
CREATE UNIQUE INDEX person_given_middle_null ON Person (given,middle) WHERE family IS NULL;
CREATE UNIQUE INDEX person_given_null_family ON Person (given,family) WHERE middle IS NULL;
CREATE UNIQUE INDEX person_null_middle_family ON Person (middle,family) WHERE given IS NULL;
-- Do not allow duplicate People table entries with two NULLs
CREATE UNIQUE INDEX person_given_null_null ON Person (given) WHERE middle IS NULL AND family IS NULL;
CREATE UNIQUE INDEX person_null_middle_null ON Person (middle) WHERE given IS NULL AND family IS NULL;
CREATE UNIQUE INDEX person_null_null_family ON Person (family) WHERE given IS NULL AND middle IS NULL;

-- Application or user insert on these tables should start at 10000
-- This leaves room for global constants that are guaranteed to exist
ALTER SEQUENCE word_id_seq RESTART WITH 10000;
ALTER SEQUENCE sentence_id_seq RESTART WITH 10000;
ALTER SEQUENCE person_id_seq RESTART WITH 10000;
ALTER SEQUENCE company_id_seq RESTART WITH 10000;
ALTER SEQUENCE individual_id_seq RESTART WITH 20000;
ALTER SEQUENCE given_id_seq RESTART WITH 10000;
ALTER SEQUENCE family_id_seq RESTART WITH 10000;
