-- The MIT License (MIT) Copyright (c) 2014-2015 Stephen A Jazdzewski
-- Do not allow duplicate words based on case
-- upper(value) is not allowed in an in-table constraint
CREATE UNIQUE INDEX word_value ON Word(culture,UPPER(value));

-- Untested
CREATE INDEX sentence_value ON Sentence(culture,UPPER(value));
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
DROP SEQUENCE IF EXISTS span_shared_id_seq;
CREATE SEQUENCE span_shared_id_seq START WITH 10000;
DROP SEQUENCE IF EXISTS cargo_id_seq;
CREATE SEQUENCE cargo_id_seq START WITH 100;
CREATE SEQUENCE IF NOT EXISTS individualjob_id_seq START WITH 100;

-- Application or user insert on these tables should start at 2000000
-- This leaves room for global constants that are guaranteed to exist
SELECT setval('word_id_seq', 2000000, false);
SELECT setval('wordplural_id_seq', 1000, false);
SELECT setval('sentence_id_seq', 2000000, false);
SELECT setval('paragraph_id_seq', 2000000, false);
SELECT setval('name_id_seq', 2000000, false);
SELECT setval('entity_id_seq', 2000000, false);
SELECT setval('individual_id_seq', 4000000, false);
SELECT setval('given_id_seq', 2000000, false);
SELECT setval('family_id_seq', 2000000, false);
SELECT setval('email_id_seq', 2000000, false);
SELECT setval('listindividualname_listindividual_seq', 2000000, false);
SELECT setval('path_id_seq', 2000000, false);
-- IDs for DMA 0 - 999, for MSA 1000-99999.  Current schema will only support one type of marketing area number
SELECT setval('area_id_seq', 100000, false);
SELECT setval('location_id_seq', 10000, false);
SELECT setval('country_id_seq', 10000, false);
SELECT setval('phone_id_seq', 10000, false);
SELECT setval('periodname_period_seq', 1000, false);
-- Untested
SELECT setval('application_id_seq', 10000, false);
SELECT setval('version_id_seq', 10000, false);
SELECT setval('release_id_seq', 10000, false);
SELECT setval('applicationrelease_id_seq', 10000, false);
SELECT setval('part_id_seq', 10000, false);
SELECT setval('assemblyapplicationrelease_id_seq', 10000, false);
SELECT setval('site_id_seq', 1000, false);
SELECT setval('agentstring_id_seq', 1000, false);
SELECT setval('session_id_seq', 1000, false);
SELECT setval('edge_id_seq', 10000, false);
SELECT setval('vertexname_vertex_seq', 10000, false);
SELECT setval('accountName_account_seq', 1000, false);
SELECT setval('ledgerName_ledger_seq', 1000, false);
SELECT setval('journalName_journal_seq', 1000, false);
SELECT setval('bookName_book_seq', 1000, false);
SELECT setval('accountname_account_seq', 1000, false);
SELECT setval('jobname_job_seq', 1000, false);
SELECT setval('schedulename_schedule_seq', 1000, false);
SELECT setval('entry_id_seq', 1, false);
SELECT setval('journalentry_id_seq', 1000, false);
SELECT setval('bill_id_seq', 1000, false);
