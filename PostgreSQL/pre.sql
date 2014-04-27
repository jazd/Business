SET search_path TO Business,"$user",public;

-- Functions

-- Brute force birthday calculation
CREATE OR REPLACE FUNCTION birthday(date)
 returns varchar(10)
AS $$
SELECT
CASE WHEN extract(month FROM $1) < extract(month FROM NOW()) THEN
 -- past
  (extract(year FROM NOW())::integer + 1) || '-' ||  extract(month FROM $1) || '-' ||  extract(day FROM $1)
ELSE
 CASE WHEN extract(month FROM $1) = extract(month FROM NOW())
   AND extract(day FROM $1) < extract(day FROM NOW()) THEN
  -- past
  (extract(year FROM NOW())::integer + 1) || '-' ||  extract(month FROM $1) || '-' ||  extract(day FROM $1)
 ELSE
   -- future
  extract(year FROM NOW()) || '-' ||  extract(month FROM $1) || '-' ||  extract(day FROM $1)
 END
END AS birthday
$$ language sql immutable strict;

CREATE OR REPLACE FUNCTION days_until_birthday(date)
 returns integer
AS $$
 SELECT
 CAST(extract(days FROM CAST(birthday($1) AS date)-NOW()) AS integer) AS days
$$ language sql immutable strict;
