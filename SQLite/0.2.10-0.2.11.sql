-- =============================================================================
-- Business schema upgrade: 0.2.10 -> 0.2.11 (SQLite shop)
-- =============================================================================
--
-- Living upgrade path while 0.2.11 is unreleased. Apply to a shop DB that was
-- built or upgraded to 0.2.10 so it reaches the same end state as a fresh
-- 0.2.11 business.sqlite3 template (DDL + seeds that Static would add).
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.10 (stop IS NULL)
--   * File backup taken (script can .backup before apply)
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.10 0.2.11
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.10 shop database)
-- ---------------------------------------------------------------------------
--
-- (Add numbered items as 0.2.11 work lands: ALTER TABLE, CREATE INDEX,
--  CREATE VIEW, seed INSERTs that fresh builds get via Static/.)
PRAGMA foreign_keys = ON;
ALTER TABLE Bill ADD COLUMN shipfrom INTEGER REFERENCES Address(id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE Bill ADD COLUMN shipto INTEGER REFERENCES Address(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.11).
--
-- =============================================================================

-- Placeholder so an empty hop is still a valid sqlite3 input file.
SELECT 1;
