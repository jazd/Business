-- The MIT License (MIT) Copyright (c) 2014-2018 Stephen A Jazdzewski
-- Officially, PostgreSQL only has "functions"
-- These links may help
-- http://www.sqlines.com/postgresql/stored_procedures_functions
-- http://www.sqlines.com/postgresql/how-to/return_result_set_from_stored_procedure
SET search_path TO Business,"$user",public;

-- Return the Id of a culture based word
-- It is inserted if it does not already exist
-- Concurrent safe: re-check under lock + ON CONFLICT on word_value; lock always released
