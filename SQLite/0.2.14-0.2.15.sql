-- =============================================================================
-- Business schema upgrade: 0.2.14 -> 0.2.15 (SQLite shop)
-- =============================================================================
--
-- Released hop 0.2.14 -> 0.2.15. Apply to a shop DB that was
-- built or upgraded to 0.2.14. Living work for the next version is
-- SQLite/0.2.15-0.2.16.sql.
--
-- Fresh shops: make business.sqlite3 / make rebuild-business-sqlite3.
-- Do not use this script for a greenfield create.
--
-- PRECONDITIONS (enforced by scripts/upgrade-sqlite.sh)
--   * SQLITE_DB points at the live shop file
--   * Active SchemaVersion is Business 0.2.14 (stop IS NULL)
--   * A downloaded 0.2.14 business.sqlite3 may still report 0.2.11.
--     upgrade-sqlite.sh treats that file as 0.2.14 when Entitlement and
--     SchemaVersions are already present.
--
-- HOW TO RUN
--   export SQLITE_DB=$HOME/business-shop/business.sqlite3
--   ./scripts/upgrade-sqlite.sh 0.2.14 0.2.15
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.14 shop database)
-- ---------------------------------------------------------------------------
--
--  1) EntitlementCurrent compares ends to CURRENT_TIMESTAMP. SQLite has no
--     ClientNow().
--  2) JournalReport and LedgerReport totals sum cent-rounded row amounts.
--     Stored JournalEntry.amount values stay at 4 decimal places.
--  3) ContentElement.name and ContentElement.type are integer columns.
--     Each is a GetIdentifier id (Word.culture is null). They are set
--     together, and only when word, sentence, and paragraph are all null.
--     Bash SetContentElement stores them. SetFormatAttribute and
--     StopFormatAttribute store name, value, and target with GetIdentifier.
--  4) ContentElements, ContentHistory, ContentElementAttributes, and
--     FormatAttributes read those identifier words from Word where
--     culture is null. Kind dynamic is a name and type with no word,
--     sentence, or paragraph. Text stays on culture 1033 through the
--     I18N views. SQLite has no ContentBody.
--  5) Notice sentences gain es-MX text on the same ids as en-US, when
--     those English sentences are already stored.
--  6) ContentElement.squash is a nullable integer. Null means the element
--     renders alone. Bash SetContentElement stores GetIdentifier of the
--     tenth argument when that string is set. ContentElements and
--     ContentHistory return that culture-null word. Null stays null.
--  7) IndividualSessions.tokenType reads Word where culture is null.
--     Bash SetCampaign stores the channel with GetIdentifier.
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.15). The released hop
-- stamps unless STAMP_VERSION=0.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

ALTER TABLE ContentElement ADD COLUMN name integer;
ALTER TABLE ContentElement ADD COLUMN type integer;
ALTER TABLE ContentElement ADD COLUMN squash integer;

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

DROP VIEW IF EXISTS ContentElementAttributes;
DROP VIEW IF EXISTS ContentElements;
DROP VIEW IF EXISTS ContentHistory;
DROP VIEW IF EXISTS FormatAttributes;

CREATE VIEW FormatAttributes AS
SELECT FormatAttribute.format,
 Name.value AS name,
 Value.value AS value,
 Target.value AS target,
 FormatAttribute.created
FROM FormatAttribute
JOIN Word AS Name ON Name.id = FormatAttribute.name AND Name.culture IS NULL
LEFT JOIN Word AS Value ON Value.id = FormatAttribute.value AND Value.culture IS NULL
LEFT JOIN Word AS Target ON Target.id = FormatAttribute.target AND Target.culture IS NULL
WHERE FormatAttribute.stop IS NULL;

CREATE VIEW ContentElements AS
SELECT ContentEdition.content,
 ContentEdition.id AS edition,
 ContentElement.sequence,
 CASE
  WHEN ContentElement.word IS NOT NULL THEN 'word'
  WHEN ContentElement.sentence IS NOT NULL THEN 'sentence'
  WHEN ContentElement.paragraph IS NOT NULL THEN 'paragraph'
  WHEN ContentElement.name IS NOT NULL AND ContentElement.type IS NOT NULL THEN 'dynamic'
  ELSE NULL
 END AS kind,
 COALESCE(ContentElement.word, ContentElement.sentence, ContentElement.paragraph) AS element,
 COALESCE(I18NWord.value, I18NSentence.value, I18NParagraph.value) AS value,
 ContentElement.format,
 ContentEdition.created,
 Argument.value AS argument,
 IdentName.value AS identifier,
 IdentType.value AS identifierType,
 SquashWord.value AS squash
FROM ContentEdition
JOIN ContentElement ON ContentElement.edition = ContentEdition.id
LEFT JOIN I18NWord ON I18NWord.id = ContentElement.word
LEFT JOIN I18NSentence ON I18NSentence.id = ContentElement.sentence
LEFT JOIN I18NParagraph ON I18NParagraph.id = ContentElement.paragraph
LEFT JOIN I18NWord AS Argument ON Argument.id = ContentElement.argument
LEFT JOIN Word AS IdentName ON IdentName.id = ContentElement.name AND IdentName.culture IS NULL
LEFT JOIN Word AS IdentType ON IdentType.id = ContentElement.type AND IdentType.culture IS NULL
LEFT JOIN Word AS SquashWord ON SquashWord.id = ContentElement.squash AND SquashWord.culture IS NULL
WHERE ContentEdition.stop IS NULL;

CREATE VIEW ContentElementAttributes AS
SELECT ContentElements.content,
 ContentElements.edition,
 ContentElements.sequence,
 ContentElements.kind,
 ContentElements.element,
 ContentElements.value,
 ContentElements.format,
 FormatAttributes.name,
 FormatAttributes.value AS attribute,
 FormatAttributes.target,
 ContentElements.identifier,
 ContentElements.identifierType,
 ContentElements.squash
FROM ContentElements
JOIN FormatAttributes ON FormatAttributes.format = ContentElements.format;

CREATE VIEW ContentHistory AS
SELECT ContentEdition.content,
 ContentEdition.id AS edition,
 ContentElement.sequence,
 CASE
  WHEN ContentElement.word IS NOT NULL THEN 'word'
  WHEN ContentElement.sentence IS NOT NULL THEN 'sentence'
  WHEN ContentElement.paragraph IS NOT NULL THEN 'paragraph'
  WHEN ContentElement.name IS NOT NULL AND ContentElement.type IS NOT NULL THEN 'dynamic'
  ELSE NULL
 END AS kind,
 COALESCE(ContentElement.word, ContentElement.sentence, ContentElement.paragraph) AS element,
 COALESCE(I18NWord.value, I18NSentence.value, I18NParagraph.value) AS value,
 ContentElement.format,
 ContentEdition.stop,
 ContentEdition.created,
 IdentName.value AS identifier,
 IdentType.value AS identifierType,
 SquashWord.value AS squash
FROM ContentEdition
JOIN ContentElement ON ContentElement.edition = ContentEdition.id
LEFT JOIN I18NWord ON I18NWord.id = ContentElement.word
LEFT JOIN I18NSentence ON I18NSentence.id = ContentElement.sentence
LEFT JOIN I18NParagraph ON I18NParagraph.id = ContentElement.paragraph
LEFT JOIN Word AS IdentName ON IdentName.id = ContentElement.name AND IdentName.culture IS NULL
LEFT JOIN Word AS IdentType ON IdentType.id = ContentElement.type AND IdentType.culture IS NULL
LEFT JOIN Word AS SquashWord ON SquashWord.id = ContentElement.squash AND SquashWord.culture IS NULL;

INSERT INTO Sentence (id, culture, value, length)
SELECT s.id, 2058, 'Aquí está el aviso', length('Aquí está el aviso')
FROM Sentence AS s
WHERE s.culture = 1033
 AND s.value = 'Here is the notice'
 AND NOT EXISTS (
  SELECT 1 FROM Sentence AS t WHERE t.id = s.id AND t.culture = 2058
 );
INSERT INTO Sentence (id, culture, value, length)
SELECT s.id, 2058, 'Artículos listos', length('Artículos listos')
FROM Sentence AS s
WHERE s.culture = 1033
 AND s.value = 'Items ready'
 AND NOT EXISTS (
  SELECT 1 FROM Sentence AS t WHERE t.id = s.id AND t.culture = 2058
 );

DROP VIEW IF EXISTS IndividualSessions;
CREATE VIEW IndividualSessions AS
WITH bound (individual, sessionCredential, bound) AS (
 SELECT individual, sessionCredential, created
 FROM IndividualSessionCreated
 UNION
 SELECT Credential.individual, SessionCredential.id, SessionCredential.created
 FROM SessionCredential
 JOIN Credential ON Credential.id = SessionCredential.credential
  AND Credential.revoked IS NULL
  AND Credential.individual IS NOT NULL
)
SELECT
 bound.individual,
 COALESCE(People.fullName, Entities.name) AS individualName,
 Session.id AS session,
 SessionToken.token,
 Type.value AS tokenType,
 SessionToken.siteApplicationRelease,
 Site.id AS site,
 SessionCredential.id AS sessionCredential,
 SessionCredential.credential,
 Credential.username,
 EmailAddress.value AS email,
 bound.bound,
 Session.touched,
 COALESCE(SessionToken.created, Session.created) AS created,
 SiteName.value AS siteName,
 Session.culture
FROM bound
JOIN SessionCredential ON SessionCredential.id = bound.sessionCredential
JOIN Session ON Session.id = SessionCredential.session
JOIN Credential ON Credential.id = SessionCredential.credential
 AND Credential.revoked IS NULL
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN Word AS Type ON Type.id = SessionToken.type AND Type.culture IS NULL
LEFT JOIN SiteApplicationRelease ON SiteApplicationRelease.id = SessionToken.siteApplicationRelease
LEFT JOIN Site ON Site.id = SiteApplicationRelease.site
LEFT JOIN I18NSentence AS SiteName ON SiteName.id = Site.name
LEFT JOIN People ON People.individual = bound.individual
LEFT JOIN Entities ON Entities.individual = bound.individual
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email;
