-- Triggers for Word, Sentence and Paragraph
-- emulated serial since id is not Primary Key
CREATE TRIGGER auto_increment_sequence_word
AFTER INSERT ON word
WHEN new.id = 0
BEGIN
    UPDATE word
    SET id = (SELECT IFNULL(MAX(id), 0) + 1 FROM word)
    WHERE rowid = new.rowid;
END;

CREATE TRIGGER auto_increment_sequence_sentence
AFTER INSERT ON sentence
WHEN new.id = 0
BEGIN
    UPDATE sentence
    SET id = (SELECT IFNULL(MAX(id), 0) + 1 FROM sentence)
    WHERE rowid = new.rowid;
END;

CREATE TRIGGER auto_increment_sequence_paragraph
AFTER INSERT ON paragraph
WHEN new.id = 0
BEGIN
    UPDATE paragraph
    SET id = (SELECT IFNULL(MAX(id), 0) + 1 FROM paragraph)
    WHERE rowid = new.rowid;
END;

-- One active IndividualPath per (individual, type, path); history keeps stopped rows
CREATE UNIQUE INDEX individualPath_individual_type_path_unstopped
 ON IndividualPath (individual, type, path)
 WHERE stop IS NULL;

-- One active SessionPath per (session, type, path); history keeps stopped rows
CREATE UNIQUE INDEX sessionPath_session_type_path_unstopped
 ON SessionPath (session, type, path)
 WHERE stop IS NULL;

-- One unrevoked PathPassword per (path, password); history keeps revoked rows
CREATE UNIQUE INDEX pathPassword_path_password_unrevoked
 ON PathPassword (path, password)
 WHERE revoked IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS contentedition_content_open
 ON ContentEdition (content)
 WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contentelement_edition_sequence_key
 ON ContentElement (edition, sequence);
CREATE UNIQUE INDEX IF NOT EXISTS contentsite_site_content_open
 ON ContentSite (site, content)
 WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contentlist_listname_content_open
 ON ContentList (listName, content)
 WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS campaignrun_campaign_open
 ON CampaignRun (campaign)
 WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS campaigncontent_campaign_content_open
 ON CampaignContent (campaign, content)
 WHERE stop IS NULL;

-- One current entitlement per individual, list name, list set, and source.
-- A null list set is its own key.
CREATE UNIQUE INDEX IF NOT EXISTS entitlement_current_set
 ON Entitlement (individual, listName, listSet, source)
 WHERE stopped IS NULL AND listSet IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS entitlement_current_noset
 ON Entitlement (individual, listName, source)
 WHERE stopped IS NULL AND listSet IS NULL;

-- Update the next in sequence for id
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'WordPlural';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Edge';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Part';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'AssemblyApplicationRelease';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'SiteApplicationRelease';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Site';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'SessionCredential';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Session';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Credential';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Password';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'AgentString';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'ApplicationRelease';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Release';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Application';
UPDATE sqlite_sequence SET seq = 2000000 WHERE name = 'Name';
UPDATE sqlite_sequence SET seq = 2000000 WHERE name = 'Entity';
UPDATE sqlite_sequence SET seq = 2000000 WHERE name = 'Given';
UPDATE sqlite_sequence SET seq = 2000000 WHERE name = 'Family';
UPDATE sqlite_sequence SET seq = 2000000 WHERE name = 'Email';
UPDATE sqlite_sequence SET seq = 2000000 WHERE name = 'Path';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Phone';
UPDATE sqlite_sequence SET seq = 100000 WHERE name = 'Area';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Period';
UPDATE sqlite_sequence SET seq = 20000 WHERE name = 'Location';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Postal';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Country';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'DateRange';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'TimeOfDay';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'DayOfWeek';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'MonthDay';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'Month';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'PeriodName';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'Attribute';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'LedgerName';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'JournalName';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'BookName';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'AccountName';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'Entry';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'JournalEntry';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Bill';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Version';

-- Amounts are text with two decimal places. Total is the last row.
-- SQLite keeps ORDER BY on a view only when LIMIT is present; LIMIT -1 returns every row.
DROP VIEW IF EXISTS JournalReport;
CREATE VIEW JournalReport AS
SELECT journal,
 journalName,
 entry,
 account,
 type,
 ledger,
 ledgerName,
 CASE WHEN debit IS NULL THEN NULL ELSE printf('%.2f', debit) END AS debit,
 CASE WHEN credit IS NULL THEN NULL ELSE printf('%.2f', credit) END AS credit,
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
 COALESCE(SUM(ROUND(debit, 2)), 0) AS debit,
 COALESCE(SUM(ROUND(credit, 2)), 0) AS credit,
 NULL AS rightSide,
 NULL AS created,
 1 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
) AS JournalReportLines
ORDER BY sortTotal, entry, rightSide
LIMIT -1;

-- Accounts, Ledgers, and LedgerBalance are the schema.xml views.
-- LedgerReport is replaced here. Amounts are two-decimal text. Total is last.
-- SQLite keeps ORDER BY on a view only when LIMIT is present; LIMIT -1 returns every row.
DROP VIEW IF EXISTS LedgerReport;

CREATE VIEW LedgerReport AS
SELECT ledger,
 sequence,
 ledgerName,
 accountName,
 typeName,
 CASE WHEN debit IS NULL THEN NULL ELSE printf('%.2f', debit) END AS debit,
 CASE WHEN credit IS NULL THEN NULL ELSE printf('%.2f', credit) END AS credit
FROM (
SELECT ledger,
 sequence,
 ledgerName,
 accountName,
 typeName,
 debit,
 credit,
 0 AS sortTotal
FROM LedgerBalance
UNION ALL
SELECT ledger,
 NULL AS sequence,
 ledgerName,
 'Total' AS accountName,
 NULL AS typeName,
 COALESCE(SUM(ROUND(debit, 2)), 0) AS debit,
 COALESCE(SUM(ROUND(credit, 2)), 0) AS credit,
 1 AS sortTotal
FROM LedgerBalance
GROUP BY ledger,
 ledgerName
) AS LedgerReportLines
ORDER BY ledger, sortTotal, sequence
LIMIT -1;

-- EntitlementCurrent on SQLite uses CURRENT_TIMESTAMP. ClientNow() is PostgreSQL.
DROP VIEW IF EXISTS EntitlementCurrent;
CREATE VIEW EntitlementCurrent AS
SELECT Entitlement.id,
 Entitlement.individual,
 Entitlement.listName,
 ListName.value AS listNameValue,
 Entitlement.listSet,
 ListSet.value AS listSetValue,
 Entitlement.source,
 Source.value AS sourceValue,
 Entitlement.status,
 Status.value AS statusValue,
 Entitlement.stopReason,
 StopReason.value AS stopReasonValue,
 Entitlement.starts,
 Entitlement.ends,
 Entitlement.batch,
 Batch.value AS batchValue,
 Entitlement.stopped,
 Entitlement.created
FROM Entitlement
LEFT JOIN I18NWord AS ListName ON ListName.id = Entitlement.listName
LEFT JOIN I18NWord AS ListSet ON ListSet.id = Entitlement.listSet
LEFT JOIN I18NWord AS Source ON Source.id = Entitlement.source
LEFT JOIN I18NWord AS Status ON Status.id = Entitlement.status
LEFT JOIN I18NWord AS StopReason ON StopReason.id = Entitlement.stopReason
LEFT JOIN I18NSentence AS Batch ON Batch.id = Entitlement.batch
WHERE Entitlement.stopped IS NULL
 AND (Entitlement.ends IS NULL OR Entitlement.ends > CURRENT_TIMESTAMP);
