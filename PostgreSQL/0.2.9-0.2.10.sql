-- =============================================================================
-- Business schema upgrade: 0.2.9 -> 0.2.10 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.10 is unreleased. Keep this file in sync with
-- develop (procedures.d, schema.xml, post.sql, Static seeds) so a database
-- installed at 0.2.9 can reach the same end state as a fresh 0.2.10 build.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.9 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.9-0.2.10.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.9 database)
-- ---------------------------------------------------------------------------
--
-- (Add numbered items here as 0.2.10 work lands: DDL ALTERs, new indexes,
--  static seeds, CREATE OR REPLACE of changed procedures from procedures.d,
--  view drop/recreate when column types change, etc.)
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '10') — stops 0.2.9, activates
--      0.2.10. Keep this as the last substantive step.
--
-- ---------------------------------------------------------------------------
-- Other release package changes (since tag 0.2.9)
-- ---------------------------------------------------------------------------
--
-- (Optional notes for packaging, diagrams, Bash helpers, README — not all
--  of these run inside this psql script.)
--
-- TESTING
--   * make pgsqldb on develop (fresh 0.2.10-shaped DB)
--   * Upgrade a copy of production (or test) 0.2.9 with this script
--   * BusinessSchema.PostgreSqlSuite (~24 intentional exceptions on
--     XcepteionRequired)
--
-- =============================================================================
\set ON_ERROR_STOP on

DO $$
BEGIN
 -- Check: Business schema exists
 IF NOT EXISTS (
  SELECT true
  FROM pg_namespace
  WHERE nspname = 'business'
 ) THEN
  RAISE EXCEPTION 'Schema "Business" does not exist in this database';
 END IF;

 SET search_path TO business, public;

 -- Require current schema version 0.2.9
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
   AND patch.value = '9'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.9';
 END IF;

END $$;

SET search_path TO business, public;

-- ---------------------------------------------------------------------------
-- 0.2.10: (pending) DDL / data / procedure changes
-- ---------------------------------------------------------------------------
-- Append CREATE OR REPLACE FUNCTION bodies from procedures.d as needed,
-- or re-embed a full procedure refresh when many signatures change.
-- Prefer small, reviewable sections with clear comments.


-- Mark schema upgraded to 0.2.10
SELECT SetSchemaVersion('Business', '0', '2', '10');
