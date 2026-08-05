-- Individual / Entity / Name (diagram: individual)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetGiven (
 inGiven varchar
) RETURNS integer AS $$
DECLARE
 given_id integer;
BEGIN
 IF inGiven IS NOT NULL THEN
  SELECT id INTO given_id
  FROM Given
  WHERE Given.value = inGiven
  LIMIT 1;
  IF given_id IS NULL THEN
   -- Be sure to process any single given one at a time without the need of a transaction or locking Given table
   PERFORM pg_advisory_lock(hashtext(inGiven));
   BEGIN
   INSERT INTO Given (value) (
    SELECT inGiven
    FROM DUAL
    LEFT JOIN Given AS exists ON exists.value = inGiven
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(hashtext(inGiven));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inGiven));
     RAISE;
   END;
   SELECT id INTO given_id
   FROM Given
   WHERE Given.value = inGiven
   LIMIT 1;
  END IF;
 END IF;
 RETURN given_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFamily (
 inFamily varchar
) RETURNS integer AS $$
DECLARE
 family_id integer;
BEGIN
 IF inFamily IS NOT NULL THEN
  SELECT id INTO family_id
  FROM Family
  WHERE Family.value = inFamily
  LIMIT 1;
  IF family_id IS NULL THEN
   -- Be sure to process any single family one at a time without the need of a transaction or locking Family table
   PERFORM pg_advisory_lock(hashtext(inFamily));
   BEGIN
   INSERT INTO Family (value) (
    SELECT inFamily
    FROM DUAL
    LEFT JOIN Family AS exists ON exists.value = inFamily
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(hashtext(inFamily));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inFamily));
     RAISE;
   END;
   SELECT id INTO family_id
   FROM Family
   WHERE Family.value = inFamily
   LIMIT 1;
  END IF;
 END IF;
 RETURN family_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetName (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar
) RETURNS integer AS $$
DECLARE
 first_id integer;
 middle_id integer;
 last_id integer;
 name_id integer;
BEGIN
 IF inFirst IS NOT NULL OR inMiddle IS NOT NULL OR inLast IS NOT NULL THEN
  -- get given and family values
  first_id := (SELECT GetGiven(inFirst));
  middle_id := (SELECT GetGiven(inMiddle));
  last_id := (SELECT GetFamily(inLast));
  SELECT id INTO name_id
  FROM Name
  WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
    AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
    AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
  LIMIT 1;
  IF name_id IS NULL THEN
   -- Be sure to process any single first one at a time without the need of a transaction or locking Name table
   PERFORM pg_advisory_lock(first_id);
   BEGIN
   INSERT INTO Name (given, middle, family) (
    SELECT first_id, middle_id, last_id
    FROM DUAL
    LEFT JOIN Name AS exists ON
         ((exists.given = first_id) OR (exists.given IS NULL AND first_id IS NULL))
     AND ((exists.middle = middle_id) OR (exists.middle IS NULL AND middle_id IS NULL))
     AND ((exists.family = last_id) OR (exists.family IS NULL AND last_id IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(first_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(first_id);
     RAISE;
   END;
   SELECT id INTO name_id
   FROM Name
   WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
     AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
     AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN name_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetIndividualPerson (
 inHonorific varchar, -- prefix
 inFirst varchar,
 inMiddle varchar,
 inLast varchar,
 inSuffix varchar,
 inPost varchar,
 inBirth date, -- Can't be null
 inBirthLocation integer,
 inGoesBy varchar,
 inDeath date
) RETURNS bigint AS $$
DECLARE
 name_id integer;
 prefix_id integer;
 suffix_id integer;
 post_id integer;
 goesBy_id integer;
 lockID bigint;
 individual_id bigint;
BEGIN
 -- Check for possible duplicate before inserting Name
 individual_id := (
   SELECT exists.id
   FROM DUAL -- If first, last and birthday match any existing, consider it a duplicate and refuse to insert new Individual with this function
   LEFT JOIN Given ON Given.value = inFirst
   LEFT JOIN Family ON Family.value = inLast
   LEFT JOIN Name ON ((Name.given = Given.id) OR (Name.given IS NULL AND Given.id IS NULL))
    AND ((Name.family = Family.id) OR (Name.family IS NULL AND Family.id IS NULL))
   LEFT JOIN Individual AS exists ON exists.name IN (name_id, Name.id)
    AND ((CAST(exists.birth AS DATE) = inBirth) OR (inBirth IS NULL))
   LIMIT 1
 );

 IF individual_id IS NULL THEN
  name_id := (SELECT GetName(inFirst,inMiddle,inLast));
  prefix_id := (SELECT GetWord(inHonorific));
  suffix_id := (SELECT GetWord(inSuffix));
  post_id := (SELECT GetWord(inPost));
  goesBy_id := (SELECT GetGiven(inGoesBy));

  IF name_id IS NOT NULL AND inBirth IS NOT NULL THEN
   -- Be sure to process any single birthdate one at a time without the need of a transaction or locking the Individual table
   lockID := extract(epoch FROM inBirth)::bigint;
   PERFORM pg_advisory_lock(lockID);
   BEGIN
   INSERT INTO Individual(name, prefix, suffix, post, goesBy, birth, location, death) VALUES (name_id, prefix_id, suffix_id, post_id, goesBy_id, inBirth, inBirthLocation, inDeath);
   PERFORM pg_advisory_unlock(lockID);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lockID);
     RAISE;
   END;
  END IF;

  individual_id := (
   SELECT id
   FROM Individual
   WHERE Individual.name = name_id
   AND (CAST(Individual.birth AS DATE) = inBirth) -- Null birth inserts are not allowd in this function
   AND ((Individual.goesBy = goesBy_id) OR (goesBy_id IS NULL))
   AND ((CAST(Individual.death AS DATE) = inDeath) OR (Individual.death IS NULL AND inDeath IS NULL))
   LIMIT 1
  );
 END IF;

 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetIndividualPerson (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar,
 inBirth date, -- Can't be null
 inGoesBy varchar,
 inDeath date
) RETURNS bigint AS $$
BEGIN
 RETURN GetIndividualPerson(NULL, inFirst, inMiddle, inLast, NULL, NULL, inBirth, NULL, inGoesBy, inDeath);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetEntityName (
 inName varchar
) RETURNS integer AS $$
DECLARE
 entity_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  SELECT id INTO entity_id
  FROM Entity
  WHERE UPPER(Entity.name) = UPPER(inName)
  LIMIT 1;
  IF entity_id IS NULL THEN
   -- Be sure to process any single name one at a time without the need of a transaction or locking the Entity table
   PERFORM pg_advisory_lock(hashtext(inName));
   BEGIN
   INSERT INTO Entity (name)
   SELECT inName
   FROM DUAL
   LEFT JOIN Entity AS exists ON UPPER(exists.name) = UPPER(inName)
   WHERE exists.id IS NULL
   LIMIT 1;
   PERFORM pg_advisory_unlock(hashtext(inName));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inName));
     RAISE;
   END;
   SELECT id INTO entity_id
   FROM Entity
   WHERE UPPER(Entity.name) = UPPER(inName)
   LIMIT 1;
  END IF;
 END IF;
 RETURN entity_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar,
 inFormed date,
 inGoesBy varchar,
 inDissolved date
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 goesBy_id integer;
 individual_id bigint;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  goesBy_id := (SELECT GetGiven(inGoesBy));
  SELECT id INTO individual_id
  FROM Individual
  WHERE Individual.entity = entity_name_id
  LIMIT 1;
  IF individual_id IS NULL THEN
   -- Be sure to process any single entity name id one at a time without the need of a transaction or locking Individual table
   PERFORM pg_advisory_lock(entity_name_id);
   BEGIN
   INSERT INTO Individual (entity, goesBy, birth, death)
   SELECT entity_name_id, goesBy_id, inFormed, inDissolved
   FROM DUAL
   LEFT JOIN Individual AS exists ON exists.entity = entity_name_id
   WHERE exists.id IS NULL
   LIMIT 1;
   PERFORM pg_advisory_unlock(entity_name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(entity_name_id);
     RAISE;
   END;
   SELECT id INTO individual_id
   FROM Individual
   WHERE Individual.entity = entity_name_id
   LIMIT 1;
  END IF;
 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 individual_id bigint;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  -- Be sure to process any single entity name id one at a time without the need of a transaction or locking Individual table
  SELECT id INTO individual_id
  FROM Individual
  WHERE entity = entity_name_id
  LIMIT 1;
  IF individual_id IS NULL THEN
   PERFORM pg_advisory_lock(entity_name_id);
   BEGIN
   INSERT INTO Individual (entity) VALUES (entity_name_id) RETURNING id INTO individual_id;
   PERFORM pg_advisory_unlock(entity_name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(entity_name_id);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CreateIndividual (
) RETURNS bigint AS $$
DECLARE
BEGIN
 INSERT INTO Individual (birth) VALUES(NULL);
 RETURN (SELECT currval(pg_get_serial_sequence('individual','id')));
END;
$$ LANGUAGE plpgsql;

