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
 COALESCE(SUM(debit), 0) AS debit,
 COALESCE(SUM(credit), 0) AS credit,
 NULL AS rightSide,
 NULL AS created,
 1 AS sortTotal
FROM JournalEntries
WHERE posted IS NULL
) AS JournalReportLines
ORDER BY sortTotal, entry, rightSide
LIMIT -1;

-- Chart accounts and the ledger that lists them. LedgerReport sums open
-- journal lines (posted IS NULL) onto the chart account of the same type.
-- Amounts on LedgerReport are text with two decimal places. Total is last.
-- SQLite keeps ORDER BY on a view only when LIMIT is present; LIMIT -1 returns every row.
DROP VIEW IF EXISTS LedgerReport;
DROP VIEW IF EXISTS LedgerBalance;
DROP VIEW IF EXISTS Ledgers;
DROP VIEW IF EXISTS Accounts;

CREATE VIEW Accounts AS
SELECT AccountName.account,
 I18NSentence.value AS name,
 AccountName.type,
 TypeName.value AS typeName,
 IndividualAccount.individual,
 COALESCE(People.fullname, Entities.name) AS individualName,
 IndividualAccount.type AS individualAccountType,
 IndividualAccountType.value AS individualAccountTypeName,
 AccountName.credit,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitIncrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitDecrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditIncrease,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditDecrease
FROM AccountName
JOIN I18NSentence ON I18NSentence.id = AccountName.name
JOIN I18NWord AS TypeName ON TypeName.id = AccountName.type
LEFT JOIN IndividualAccount ON IndividualAccount.account = AccountName.account
 AND IndividualAccount.stop IS NULL
LEFT JOIN People ON People.individual = IndividualAccount.individual
LEFT JOIN Entities ON Entities.individual = IndividualAccount.individual
LEFT JOIN I18NWord AS IndividualAccountType ON IndividualAccountType.id = IndividualAccount.type;

CREATE VIEW Ledgers AS
SELECT LedgerName.ledger,
 I18NSentence.value AS name,
 LedgerAccount.sequence,
 Accounts.account,
 Accounts.name AS accountName,
 Accounts.type,
 Accounts.typeName,
 Accounts.credit,
 Accounts.debitIncrease,
 Accounts.debitDecrease,
 Accounts.creditIncrease,
 Accounts.creditDecrease
FROM LedgerName
JOIN I18NSentence ON I18NSentence.id = LedgerName.name
JOIN LedgerAccount ON LedgerAccount.ledger = LedgerName.ledger
JOIN Accounts ON Accounts.account = LedgerAccount.account;

CREATE VIEW LedgerBalance AS
SELECT Ledgers.ledger,
 Ledgers.name AS ledgerName,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName,
 SUM(JournalEntries.debit) AS debit,
 SUM(JournalEntries.credit) AS credit
FROM JournalEntries
JOIN Ledgers ON Ledgers.ledger = JournalEntries.ledger
 AND Ledgers.type = JournalEntries.type
WHERE JournalEntries.posted IS NULL
GROUP BY Ledgers.ledger,
 Ledgers.name,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName;

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
 COALESCE(SUM(debit), 0) AS debit,
 COALESCE(SUM(credit), 0) AS credit,
 1 AS sortTotal
FROM LedgerBalance
GROUP BY ledger,
 ledgerName
) AS LedgerReportLines
ORDER BY ledger, sortTotal, sequence
LIMIT -1;
