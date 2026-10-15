-- =============================================================================
-- Business schema upgrade: 0.2.15 -> 0.2.16 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.16 is unreleased. Apply to a database
-- installed at 0.2.15.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Active SchemaVersion is Business 0.2.15 (stop IS NULL)
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.15-0.2.16.sql
--
-- The script is one transaction. A failed statement rolls the change back.
--
-- Version stamp stays commented until 0.2.16 is released.
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
   AND patch.value = '15'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.15';
 END IF;
END $$;

-- SELECT SetSchemaVersion('Business', '0', '2', '16');

COMMIT;
