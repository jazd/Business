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
--     This hop adds the columns. It does not write them yet.
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

-- Mark schema upgraded to 0.2.15 when the hop body is ready for the release.
-- SELECT SetSchemaVersion('Business', '0', '2', '15');

COMMIT;
