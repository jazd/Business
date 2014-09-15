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

CREATE OR REPLACE FUNCTION days_until_birthday(birth date, asOf date)
 returns integer
AS $$
 SELECT
 CAST(extract(days FROM CAST(birthday(birth) AS date) - CAST(asOf AS timestamp)) AS integer) AS days
$$ language sql immutable strict;

-- Simulate the DUAL fake table used on other servers
DROP TABLE DUAL CASCADE;
CREATE TABLE DUAL (
 value INTEGER
);
INSERT INTO DUAL (value) VALUES (NULL); -- Only a single value
