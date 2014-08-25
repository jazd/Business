-- Do not allow duplicate words based on case
-- upper(value) is not allowed in an in-table constraint
CREATE UNIQUE INDEX word_value ON Word(culture,UPPER(value));

-- Do not allow duplicate Name table entries with a single NULL
CREATE UNIQUE INDEX name_given_middle_null ON Name (given,middle) WHERE family IS NULL;
CREATE UNIQUE INDEX name_given_null_family ON Name (given,family) WHERE middle IS NULL;
CREATE UNIQUE INDEX name_null_middle_family ON Name (middle,family) WHERE given IS NULL;
-- Do not allow duplicate Name table entries with two NULLs
CREATE UNIQUE INDEX name_given_null_null ON Name (given) WHERE middle IS NULL AND family IS NULL;
CREATE UNIQUE INDEX name_null_middle_null ON Name (middle) WHERE given IS NULL AND family IS NULL;
CREATE UNIQUE INDEX name_null_null_family ON Name (family) WHERE given IS NULL AND middle IS NULL;

-- Do not allow duplicate email addresses
CREATE UNIQUE INDEX email_username_plus_host ON Email (UPPER(username),UPPER(plus),UPPER(host));

-- Application or user insert on these tables should start at 10000
-- This leaves room for global constants that are guaranteed to exist
ALTER SEQUENCE word_id_seq RESTART WITH 10000;
ALTER SEQUENCE sentence_id_seq RESTART WITH 10000;
ALTER SEQUENCE name_id_seq RESTART WITH 10000;
ALTER SEQUENCE entity_id_seq RESTART WITH 10000;
ALTER SEQUENCE individual_id_seq RESTART WITH 20000;
ALTER SEQUENCE given_id_seq RESTART WITH 10000;
ALTER SEQUENCE family_id_seq RESTART WITH 10000;
ALTER SEQUENCE email_id_seq RESTART WITH 10000;
ALTER SEQUENCE individuallistname_individuallist_seq RESTART WITH 10000;
ALTER SEQUENCE path_id_seq RESTART WITH 10000;
