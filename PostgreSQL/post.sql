-- The MIT License (MIT) Copyright (c) 2014-2015 Stephen A Jazdzewski
-- Do not allow duplicate words based on case
-- upper(value) is not allowed in an in-table constraint
CREATE UNIQUE INDEX word_value ON Word(culture,UPPER(value));

-- Untested
CREATE UNIQUE INDEX sentence_value ON Sentence(culture,UPPER(value));
CREATE UNIQUE INDEX sentence_value_null ON Sentence(UPPER(value)) WHERE culture IS NULL;
CREATE UNIQUE INDEX release_version_null ON Release(name) WHERE build IS NULL;
CREATE UNIQUE INDEX version_null_major_minor_patch ON Version(major,minor,patch) WHERE name IS NULL;
CREATE UNIQUE INDEX version_name_major_minor_null ON Version(name,major,minor) WHERE patch IS NULL;
CREATE UNIQUE INDEX version_null_major_minor_null ON Version(major,minor) WHERE name IS NULL AND patch IS NULL;
CREATE UNIQUE INDEX AssemblyApplicationRelease_assembly_applicationRelease_null ON AssemblyApplicationRelease(assembly,applicationRelease) WHERE parent IS NULL;
CREATE UNIQUE INDEX Part_name_null_null_null ON Part(name) WHERE parent IS NULL AND version IS NULL AND serial IS NULL;
CREATE UNIQUE INDEX AgentString_null_string ON AgentString(userAgentString) WHERE agent IS NULL;
CREATE INDEX path_host ON Path(UPPER(host));
CREATE INDEX path_host_value ON Path(UPPER(host),value);

-- Session function indexes, untested
CREATE INDEX sessionCredentialFull ON SessionCredential (session,agentstring,credential,referring,fromaddress,location);
CREATE UNIQUE INDEX SessionToken_token_inSiteApplicationRelease ON SessionToken(token,siteApplicationRelease);
CREATE UNIQUE INDEX SessionToken_token_null ON SessionToken(token) WHERE siteApplicationRelease IS NULL;

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

-- Do not allow duplicate country codes
CREATE UNIQUE INDEX country_code ON Country (UPPER(code));

-- Do not allow duplicate entity names
CREATE UNIQUE INDEX entity_name ON Entity (UPPER(name));

-- Do not allow duplicate words, sentences or paragraphs when culture is NULL
-- Untested
CREATE UNIQUE INDEX word_id_culture_null ON Word (id) WHERE culture IS NULL;
CREATE UNIQUE INDEX sentence_id_culture_null ON Sentence (id) WHERE culture IS NULL;
CREATE UNIQUE INDEX paragraph_id_culture_null ON Paragraph (id) WHERE culture IS NULL;

-- Sequences
DROP SEQUENCE period_shared_id_seq;
CREATE SEQUENCE period_shared_id_seq START WITH 10000;
DROP SEQUENCE span_shared_id_seq;
CREATE SEQUENCE span_shared_id_seq START WITH 10000;

-- Application or user insert on these tables should start at 2000000
-- This leaves room for global constants that are guaranteed to exist
ALTER SEQUENCE word_id_seq RESTART WITH 2000000;
ALTER SEQUENCE sentence_id_seq RESTART WITH 2000000;
ALTER SEQUENCE paragraph_id_seq RESTART WITH 2000000;
ALTER SEQUENCE name_id_seq RESTART WITH 2000000;
ALTER SEQUENCE entity_id_seq RESTART WITH 2000000;
ALTER SEQUENCE individual_id_seq RESTART WITH 4000000;
ALTER SEQUENCE given_id_seq RESTART WITH 2000000;
ALTER SEQUENCE family_id_seq RESTART WITH 2000000;
ALTER SEQUENCE email_id_seq RESTART WITH 2000000;
ALTER SEQUENCE individuallistname_individuallist_seq RESTART WITH 2000000;
ALTER SEQUENCE path_id_seq RESTART WITH 2000000;
-- IDs for DMA 0 - 999, for MSA 1000-99999.  Current schema will only support one type of marketing area number
ALTER SEQUENCE area_id_seq RESTART WITH 100000;
ALTER SEQUENCE location_id_seq RESTART WITH 10000;
ALTER SEQUENCE country_id_seq RESTART WITH 10000;
ALTER SEQUENCE phone_id_seq RESTART WITH 10000;
ALTER SEQUENCE period_id_seq RESTART WITH 1000;
-- Untested
ALTER SEQUENCE application_id_seq RESTART WITH 10000;
ALTER SEQUENCE version_id_seq RESTART WITH 10000;
ALTER SEQUENCE release_id_seq RESTART WITH 10000;
ALTER SEQUENCE applicationrelease_id_seq RESTART WITH 10000;
ALTER SEQUENCE part_id_seq RESTART WITH 10000;
ALTER SEQUENCE assemblyapplicationrelease_id_seq RESTART WITH 10000;
ALTER SEQUENCE site_id_seq RESTART WITH 1000;
ALTER SEQUENCE agentstring_id_seq RESTART WITH 1000;
ALTER SEQUENCE session_id_seq START WITH 1000;

