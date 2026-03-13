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
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Location';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Postal';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Country';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'DateRange';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'TimeOfDay';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'DayOfWeek';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'MonthDay';
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'Month';
-- PeriodName
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'Attribute';
-- LedgerName
-- JournalName
-- BookName
-- AccountName
UPDATE sqlite_sequence SET seq = 100 WHERE name = 'Entry';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'JournalEntry';
UPDATE sqlite_sequence SET seq = 1000 WHERE name = 'Bill';
UPDATE sqlite_sequence SET seq = 10000 WHERE name = 'Version';
