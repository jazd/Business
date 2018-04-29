-- The MIT License (MIT) Copyright (c) 2017-2018 Stephen A Jazdzewski
-- Functions used in views

SET search_path TO Business,"$user",public;

-- Brute force birthday calculation
CREATE OR REPLACE FUNCTION birthday(birth date, asOf date)
 returns varchar(10)
AS $$
SELECT
CASE WHEN extract(month FROM birth) < extract(month FROM asOf) THEN
 -- past
  (extract(year FROM asOf)::integer + 1) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
ELSE
 CASE WHEN extract(month FROM birth) = extract(month FROM asOf)
   AND extract(day FROM birth) < extract(day FROM asOf) THEN
  -- past
  (extract(year FROM asOf)::integer + 1) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
 ELSE
   -- future
  extract(year FROM asOf) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
 END
END AS birthday
$$ language sql immutable strict;

CREATE OR REPLACE FUNCTION birthday(birth Date)
 returns varchar(10)
AS $$
SELECT birthday(birth, CAST(NOW() AS Date)) AS birthday;
$$ language sql immutable strict;

CREATE OR REPLACE FUNCTION days_until_birthday(birth date, asOf date)
 returns integer
AS $$
 SELECT
 CAST(extract(days FROM CAST(birthday(birth) AS date) - CAST(asOf AS timestamp)) AS integer) AS days
$$ language sql immutable strict;

-- TODO As of PostgreSQL 9.3 has the # as bitwise XOR
CREATE OR REPLACE FUNCTION XOR(boolean, boolean)
 RETURNS boolean
AS $$
SELECT ($1 AND NOT $2) OR (NOT $1 AND $2)
$$ language sql immutable strict;


-- Simulate the DUAL fake table used on other servers
DROP TABLE DUAL CASCADE;
CREATE TABLE DUAL (
 value INTEGER
);
INSERT INTO DUAL (value) VALUES (NULL); -- Only a single value

-- Normalize for databases without Interval data types
CREATE OR REPLACE FUNCTION GetInterval(varchar)
 RETURNS interval
AS $$
SELECT ($1::interval)
$$ language sql immutable strict;

-- Allow testing of date and culture based procedures and views
-- by allowing culture and now() to be overridden for testing and client connections
CREATE OR REPLACE FUNCTION ClientNow()
 RETURNS timestamp WITH TIME ZONE
AS $$
DECLARE
 injected_now timestamp WITH TIME ZONE;
BEGIN
SET LOCAL client_min_messages=warning;
CREATE TEMP TABLE IF NOT EXISTS inject_now (
 value timestamp WITH TIME ZONE
);
RESET client_min_messages;
injected_now := (SELECT value FROM inject_now LIMIT 1);
RETURN (SELECT COALESCE(injected_now,NOW()));
END;
$$ LANGUAGE plpgsql;

-- Set ClientNow
-- Stays the passed date for whole session
CREATE OR REPLACE FUNCTION ClientNow(clientNow timestamp with time zone)
 RETURNS timestamp WITH TIME ZONE
AS $$
BEGIN
SET LOCAL client_min_messages=warning;
CREATE TEMP TABLE IF NOT EXISTS inject_now (
 value timestamp WITH TIME ZONE
);
RESET client_min_messages;
DELETE FROM inject_now;
INSERT INTO inject_now(value) VALUES (clientNow);
RETURN ClientNow();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ClientCulture()
 RETURNS smallint
AS $$
DECLARE
 injected_culture smallint;
BEGIN
SET LOCAL client_min_messages=warning;
CREATE TEMP TABLE IF NOT EXISTS inject_culture (
 value smallint
);
RESET client_min_messages;
injected_culture := (SELECT value FROM inject_culture LIMIT 1);
RETURN (SELECT COALESCE(injected_culture,1033));
END;
$$ LANGUAGE plpgsql;
