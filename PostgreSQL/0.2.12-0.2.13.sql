-- =============================================================================
-- Business schema upgrade: 0.2.12 -> 0.2.13 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.13 is unreleased. Keep this file in sync with
-- develop (procedures.d, schema.xml, post.sql, Static seeds) so a database
-- installed at 0.2.12 can reach the same end state as a fresh 0.2.13 build.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.12 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.12-0.2.13.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.12 database)
-- ---------------------------------------------------------------------------
--
--  1) JournalReport: Total row sorts last (sortTotal). debit and credit stay numeric.
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '13') - last substantive step
--
-- =============================================================================

-- Total row sorts last. debit and credit stay numeric for existing CAST consumers.
CREATE OR REPLACE VIEW JournalReport ( journal, journalName, entry, account, type, ledger, ledgerName, debit, credit, rightside, created ) AS
SELECT journal,
 journalName,
 entry,
 account,
 type,
 ledger,
 ledgerName,
 debit,
 credit,
 rightSide,
 created
FROM (
SELECT journal,
 journalName,
 entry,
 accountName AS account,
 typeName AS type,
 ledger,
 ledgerName,
 debit,
 credit,
 rightSide,
 created,
 0 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
UNION ALL
SELECT NULL AS journal,
 NULL AS journalName,
 NULL AS entry,
 'Total' AS account,
 NULL AS type,
 MAX(ledger) AS ledger,
 MAX(ledgerName) AS ledgerName,
 SUM(debit) AS debit,
 SUM(credit) AS credit,
 NULL AS rightSide,
 NULL AS created,
 1 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
) AS JournalReportLines
ORDER BY sortTotal, entry, rightSide;

-- Mark schema upgraded to 0.2.13 when the hop body is ready for the release.
-- Until then, leave this commented so a partial living script is not stamped
-- as 0.2.13 on production by mistake.
-- SELECT SetSchemaVersion('Business', '0', '2', '13');
