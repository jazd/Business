-- =============================================================================
-- Business schema upgrade: 0.2.14 -> 0.2.15 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.15 is unreleased. A database installed at
-- 0.2.14 reaches the GetSite lookup below.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Active SchemaVersion is Business 0.2.14 (stop IS NULL)
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.14-0.2.15.sql
--
-- The script is one transaction. A failed statement rolls the function back.
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.14 database)
-- ---------------------------------------------------------------------------
--
--  1) GetSite returns an existing site whose name is the sentence id, or a
--     Word id with the same text. It does not rewrite Site.name and it does
--     not insert a second site for that name.
--  2) ContentElement.name and ContentElement.type are integer columns.
--     Each is a GetIdentifier id (Word.culture is null). They are set
--     together, and only when word, sentence, and paragraph are all null.
--  3) SetContentElement stores those identifiers on that write.
--     SetFormatAttribute and StopFormatAttribute store name, value, and
--     target with GetIdentifier. argument on a word stays GetWord.
--
-- Version stamp stays commented until 0.2.15 is released.
--
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

SET search_path TO business, public;

DO $$
BEGIN
 IF NOT EXISTS (
  SELECT true
  FROM schemaversion
  JOIN word AS schema ON schema.id = schemaversion.schema
  JOIN version ON version.id = schemaversion.version
  JOIN word AS major ON major.id = version.major
  JOIN word AS minor ON minor.id = version.minor
  JOIN word AS patch ON patch.id = version.patch
  WHERE schema.value = 'Business'
   AND major.value = '0'
   AND minor.value = '2'
   AND patch.value = '14'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.14';
 END IF;
END $$;

ALTER TABLE contentelement ADD COLUMN IF NOT EXISTS name integer;
ALTER TABLE contentelement ADD COLUMN IF NOT EXISTS type integer;

CREATE OR REPLACE FUNCTION GetSite (
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 site_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  SELECT id INTO site_id
  FROM Site
  WHERE name = name_id
  LIMIT 1;
  IF site_id IS NULL THEN
   SELECT Site.id INTO site_id
   FROM Site
   JOIN Word ON Word.id = Site.name
   WHERE Word.value = inName
   ORDER BY Site.id
   LIMIT 1;
  END IF;
  IF site_id IS NULL THEN
   PERFORM pg_advisory_lock(name_id);
   BEGIN
   INSERT INTO Site (name) (
    SELECT name_id AS name
    FROM Dual
    LEFT JOIN Site AS exists ON exists.name = name_id
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(name_id);
     RAISE;
   END;
   SELECT id INTO site_id
   FROM Site
   WHERE name = name_id
   LIMIT 1;
  END IF;
 END IF;
 RETURN site_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetFormatAttribute (
 inFormat integer,
 inName varchar,
 inValue varchar,
 inTarget varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 value_id integer;
 target_id integer;
BEGIN
 IF inFormat IS NOT NULL AND inName IS NOT NULL THEN
  name_id := (SELECT GetIdentifier(inName));
  value_id := (SELECT GetIdentifier(inValue));
  target_id := (SELECT GetIdentifier(inTarget));
  PERFORM pg_advisory_lock(inFormat);
  BEGIN
   INSERT INTO FormatAttribute (format, name, value, target) (
    SELECT inFormat, name_id, value_id, target_id
    FROM Dual
    LEFT JOIN FormatAttribute AS exists ON exists.format = inFormat
     AND exists.name = name_id
     AND ((exists.value = value_id) OR (exists.value IS NULL AND value_id IS NULL))
     AND ((exists.target = target_id) OR (exists.target IS NULL AND target_id IS NULL))
     AND exists.stop IS NULL
    WHERE exists.format IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inFormat);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inFormat);
    RAISE;
  END;
 END IF;
 RETURN inFormat;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopFormatAttribute (
 inFormat integer,
 inName varchar,
 inValue varchar,
 inTarget varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 value_id integer;
 target_id integer;
BEGIN
 IF inFormat IS NOT NULL AND inName IS NOT NULL THEN
  name_id := (SELECT GetIdentifier(inName));
  value_id := (SELECT GetIdentifier(inValue));
  target_id := (SELECT GetIdentifier(inTarget));
  PERFORM pg_advisory_lock(inFormat);
  BEGIN
   UPDATE FormatAttribute
   SET stop = NOW()
   WHERE format = inFormat
    AND name = name_id
    AND ((value = value_id) OR (value IS NULL AND value_id IS NULL))
    AND ((target = target_id) OR (target IS NULL AND target_id IS NULL))
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(inFormat);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inFormat);
    RAISE;
  END;
 END IF;
 RETURN inFormat;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentElement (
 inContent integer,
 inSequence integer,
 inFormat integer,
 inWord integer,
 inSentence integer,
 inParagraph integer,
 inArgument varchar,
 inName varchar,
 inType varchar
) RETURNS integer AS $$
DECLARE
 edition_id integer;
 atom_count integer;
 argument_id integer;
 name_id integer;
 type_id integer;
 dynamic boolean;
BEGIN
 atom_count := (inWord IS NOT NULL)::integer
  + (inSentence IS NOT NULL)::integer
  + (inParagraph IS NOT NULL)::integer;
 dynamic := atom_count = 0
  AND inName IS NOT NULL
  AND inType IS NOT NULL;
 IF dynamic THEN
  name_id := (SELECT GetIdentifier(inName));
  type_id := (SELECT GetIdentifier(inType));
 ELSIF atom_count = 1 AND inWord IS NOT NULL THEN
  argument_id := (SELECT GetWord(inArgument));
 END IF;
 IF inContent IS NOT NULL
  AND inSequence IS NOT NULL
  AND (
   (atom_count = 1 AND inName IS NULL AND inType IS NULL)
   OR (dynamic AND name_id IS NOT NULL AND type_id IS NOT NULL)
  ) THEN
  PERFORM pg_advisory_lock(inContent);
  BEGIN
   SELECT id INTO edition_id
   FROM ContentEdition
   WHERE content = inContent
    AND stop IS NULL
   LIMIT 1;
   IF edition_id IS NULL THEN
    INSERT INTO ContentEdition (content) (
     SELECT inContent
     FROM Dual
     LEFT JOIN ContentEdition AS exists ON exists.content = inContent
      AND exists.stop IS NULL
     WHERE exists.id IS NULL
     LIMIT 1
    );
    SELECT id INTO edition_id
    FROM ContentEdition
    WHERE content = inContent
     AND stop IS NULL
    LIMIT 1;
   END IF;
   INSERT INTO ContentElement (
    edition, sequence, word, sentence, paragraph, format, argument, name, type
   ) (
    SELECT edition_id, inSequence, inWord, inSentence, inParagraph,
     inFormat, argument_id, name_id, type_id
    FROM Dual
    LEFT JOIN ContentElement AS exists ON exists.edition = edition_id
     AND exists.sequence = inSequence
    WHERE exists.edition IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inContent);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inContent);
    RAISE;
  END;
 END IF;
 RETURN inContent;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentElement (
 inContent integer,
 inSequence integer,
 inFormat integer,
 inWord integer,
 inSentence integer,
 inParagraph integer,
 inArgument varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetContentElement(
  inContent, inSequence, inFormat, inWord, inSentence, inParagraph, inArgument, NULL, NULL
 ));
END;
$$ LANGUAGE plpgsql;

-- Mark schema upgraded to 0.2.15 when the hop body is ready for the release.
-- SELECT SetSchemaVersion('Business', '0', '2', '15');

COMMIT;
