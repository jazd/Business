-- =============================================================================
-- Business schema upgrade: 0.2.11 -> 0.2.12 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.12 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.11 so it reaches the same end state as a fresh
-- 0.2.12 business.sqlite3 template (DDL + seeds that Static would add).
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.11 (stop IS NULL)
--   * File backup taken (script can .backup before apply)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.11 0.2.12
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.11 shop database)
-- ---------------------------------------------------------------------------
--
-- (Add numbered items as 0.2.12 work lands: DDL, views, static seeds, Bash.)
--
-- SQLite does not enforce varchar(n). Width-only ALTERs are no-ops here.
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.12) when STAMP_VERSION=1.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

-- Living hop placeholder (valid no-op until 0.2.12 DDL lands).
SELECT 1;
