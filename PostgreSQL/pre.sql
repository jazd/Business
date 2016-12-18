SET search_path TO Business,"$user",public;

-- Functions used in views

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

CREATE OR REPLACE FUNCTION ClientCulture()
 RETURNS integer
AS $$
DECLARE
 injected_culture integer;
BEGIN
SET LOCAL client_min_messages=warning;
CREATE TEMP TABLE IF NOT EXISTS inject_culture (
 value integer
);
RESET client_min_messages;
injected_culture := (SELECT value FROM inject_culture LIMIT 1);
RETURN (SELECT COALESCE(injected_culture,1033));
END;
$$ LANGUAGE plpgsql;
