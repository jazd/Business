-- =============================================================================
-- Business schema upgrade: 0.2.10 -> 0.2.11 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.11 is unreleased. Keep this file in sync with
-- develop (procedures.d, schema.xml, post.sql, Static seeds) so a database
-- installed at 0.2.10 can reach the same end state as a fresh 0.2.11 build.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.10 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.10-0.2.11.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.10 database)
-- ---------------------------------------------------------------------------
--
-- (Add numbered items as 0.2.11 work lands: DDL ALTERs, indexes, static seeds,
--  CREATE OR REPLACE of changed procedures from procedures.d, view recreate.)
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '11') - last substantive step
--
-- TESTING
--   * make pgsqldb on develop (fresh 0.2.11-shaped DB)
--   * Upgrade a copy of a 0.2.10 production/test DB with this script
--   * BusinessSchema.PostgreSqlSuite (~24 intentional exceptions on
--     XcepteionRequired)
--
-- =============================================================================
\set ON_ERROR_STOP on

DO $$
BEGIN
 IF NOT EXISTS (
  SELECT true
  FROM pg_namespace
  WHERE nspname = 'business'
 ) THEN
  RAISE EXCEPTION 'Schema "Business" does not exist in this database';
 END IF;

 SET search_path TO business, public;

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
   AND patch.value = '10'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.10';
 END IF;

END $$;

SET search_path TO business, public;

-- ---------------------------------------------------------------------------
-- 0.2.11: (pending) DDL / data / procedure changes
-- ---------------------------------------------------------------------------
-- Append CREATE OR REPLACE FUNCTION bodies from procedures.d as needed,
-- or re-embed a full procedure refresh when many signatures change.
-- Prefer small, reviewable sections with clear comments.

ALTER TABLE Bill ADD COLUMN shipfrom integer;
ALTER TABLE Bill ADD COLUMN shipto integer;
ALTER TABLE Bill ADD CONSTRAINT bill_address_from FOREIGN KEY (shipfrom) REFERENCES Address (id) DEFERRABLE;
ALTER TABLE Bill ADD CONSTRAINT bill_address_to FOREIGN KEY (shipto) REFERENCES Address (id) DEFERRABLE;
--^^--


-- Mark schema upgraded to 0.2.11 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.11 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '11');
