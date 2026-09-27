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
--  1) Content, format, site/list placement, campaign tables
--  2) Partial unique indexes
--  3) I18NParagraph and content/campaign read views
--     Writers are Bash/sqlite (no PostgreSQL procedures on the shop)
--  4) Session.culture, ContentCultures, IndividualSessions.culture
--  5) Static thank-you content id 10 (en-US, fr-FR, pl-PL, es-MX)
--
-- SQLite does not enforce varchar(n). Width-only ALTERs are no-ops here.
--
-- Version stamp is performed by scripts/upgrade-sqlite.sh via SetSchemaVersion
-- after this file runs successfully (Business 0.2.12) when STAMP_VERSION=1.
--
-- =============================================================================

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS Format (
 id INTEGER PRIMARY KEY,
 name integer NOT NULL,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS FormatAttribute (
 format integer NOT NULL REFERENCES Format(id),
 name integer NOT NULL,
 value integer,
 target integer,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS formatattribute_format ON FormatAttribute (format);

CREATE TABLE IF NOT EXISTS Content (
 id INTEGER PRIMARY KEY,
 name integer NOT NULL,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ContentEdition (
 id INTEGER PRIMARY KEY,
 content integer NOT NULL REFERENCES Content(id),
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS contentedition_content ON ContentEdition (content);

CREATE TABLE IF NOT EXISTS ContentElement (
 edition integer NOT NULL REFERENCES ContentEdition(id),
 sequence integer NOT NULL,
 word integer,
 sentence integer,
 paragraph integer,
 format integer REFERENCES Format(id),
 argument integer,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS contentelement_edition_sequence ON ContentElement (edition, sequence);

CREATE TABLE IF NOT EXISTS ContentSite (
 content integer NOT NULL REFERENCES Content(id),
 site integer NOT NULL REFERENCES Site(id),
 sequence integer NOT NULL,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS contentsite_site ON ContentSite (site);

CREATE TABLE IF NOT EXISTS ContentList (
 content integer NOT NULL REFERENCES Content(id),
 listName integer NOT NULL,
 sequence integer NOT NULL,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS contentlist_listname ON ContentList (listName);

CREATE TABLE IF NOT EXISTS Campaign (
 id INTEGER PRIMARY KEY,
 name integer NOT NULL,
 listName integer NOT NULL,
 listSet integer,
 channel integer,
 period integer REFERENCES PeriodName(period),
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS CampaignRun (
 id INTEGER PRIMARY KEY,
 campaign integer NOT NULL REFERENCES Campaign(id),
 started timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS campaignrun_campaign ON CampaignRun (campaign);

CREATE TABLE IF NOT EXISTS CampaignContent (
 campaign integer NOT NULL REFERENCES Campaign(id),
 content integer NOT NULL REFERENCES Content(id),
 sequence integer NOT NULL,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS campaigncontent_campaign_sequence ON CampaignContent (campaign, sequence);

CREATE TABLE IF NOT EXISTS CampaignAttachment (
 campaign integer NOT NULL REFERENCES Campaign(id),
 path bigint NOT NULL REFERENCES Path(id),
 sequence integer NOT NULL,
 type integer,
 target integer,
 stop timestamp,
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS campaignattachment_campaign_sequence ON CampaignAttachment (campaign, sequence);

CREATE TABLE IF NOT EXISTS CampaignEvent (
 campaign integer NOT NULL REFERENCES Campaign(id),
 individual bigint NOT NULL,
 kind integer NOT NULL,
 path bigint REFERENCES Path(id),
 run integer REFERENCES CampaignRun(id),
 created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS campaignevent_campaign_individual ON CampaignEvent (campaign, individual);


CREATE UNIQUE INDEX IF NOT EXISTS contentedition_content_open
 ON ContentEdition (content) WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contentelement_edition_sequence_key
 ON ContentElement (edition, sequence);
CREATE UNIQUE INDEX IF NOT EXISTS contentsite_site_content_open
 ON ContentSite (site, content) WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contentlist_listname_content_open
 ON ContentList (listName, content) WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS campaignrun_campaign_open
 ON CampaignRun (campaign) WHERE stop IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS campaigncontent_campaign_content_open
 ON CampaignContent (campaign, content) WHERE stop IS NULL;


DROP VIEW IF EXISTS I18NParagraph;
CREATE VIEW I18NParagraph AS
SELECT ParagraphDefault.id,
 ParagraphDefault.culture AS defaultCulture,
 ClientCulture() AS clientCulture,
 COALESCE(Paragraph.culture, ParagraphDefault.culture) AS resultCulture,
 COALESCE(Paragraph.value, ParagraphDefault.value) AS value
FROM Paragraph AS ParagraphDefault
LEFT JOIN Paragraph ON Paragraph.id = ParagraphDefault.id
 AND Paragraph.culture = ClientCulture()
WHERE ParagraphDefault.culture = 1033;

DROP VIEW IF EXISTS FormatAttributes;
CREATE VIEW FormatAttributes AS
SELECT FormatAttribute.format,
 Name.value AS name,
 Value.value AS value,
 Target.value AS target,
 FormatAttribute.created
FROM FormatAttribute
LEFT JOIN I18NWord AS Name ON Name.id = FormatAttribute.name
LEFT JOIN I18NWord AS Value ON Value.id = FormatAttribute.value
LEFT JOIN I18NWord AS Target ON Target.id = FormatAttribute.target
WHERE FormatAttribute.stop IS NULL;

DROP VIEW IF EXISTS ContentElements;
CREATE VIEW ContentElements AS
SELECT ContentEdition.content,
 ContentEdition.id AS edition,
 ContentElement.sequence,
 CASE
  WHEN ContentElement.word IS NOT NULL THEN 'word'
  WHEN ContentElement.sentence IS NOT NULL THEN 'sentence'
  ELSE 'paragraph'
 END AS kind,
 COALESCE(ContentElement.word, ContentElement.sentence, ContentElement.paragraph) AS element,
 COALESCE(I18NWord.value, I18NSentence.value, I18NParagraph.value) AS value,
 ContentElement.format,
 ContentEdition.created,
 Argument.value AS argument
FROM ContentEdition
JOIN ContentElement ON ContentElement.edition = ContentEdition.id
LEFT JOIN I18NWord ON I18NWord.id = ContentElement.word
LEFT JOIN I18NSentence ON I18NSentence.id = ContentElement.sentence
LEFT JOIN I18NParagraph ON I18NParagraph.id = ContentElement.paragraph
LEFT JOIN I18NWord AS Argument ON Argument.id = ContentElement.argument
WHERE ContentEdition.stop IS NULL;

DROP VIEW IF EXISTS ContentElementPlurals;
CREATE VIEW ContentElementPlurals AS
SELECT ContentEdition.content,
 ContentEdition.id AS edition,
 ContentElement.sequence,
 Argument.value AS argument,
 ContentElement.word,
 Forms.singular,
 Forms.zero,
 Forms.two,
 Forms.few,
 Forms.many
FROM ContentEdition
JOIN ContentElement ON ContentElement.edition = ContentEdition.id
 AND ContentElement.word IS NOT NULL
 AND ContentElement.argument IS NOT NULL
LEFT JOIN I18NWord AS Argument ON Argument.id = ContentElement.argument
LEFT JOIN WordPlurals AS Forms ON Forms.word = ContentElement.word
 AND Forms.culture = COALESCE(
  (SELECT w.culture FROM Word w WHERE w.id = ContentElement.word AND w.culture = ClientCulture() LIMIT 1),
  1033)
WHERE ContentEdition.stop IS NULL;

DROP VIEW IF EXISTS ContentHistory;
CREATE VIEW ContentHistory AS
SELECT ContentEdition.content,
 ContentEdition.id AS edition,
 ContentElement.sequence,
 CASE
  WHEN ContentElement.word IS NOT NULL THEN 'word'
  WHEN ContentElement.sentence IS NOT NULL THEN 'sentence'
  ELSE 'paragraph'
 END AS kind,
 COALESCE(ContentElement.word, ContentElement.sentence, ContentElement.paragraph) AS element,
 COALESCE(I18NWord.value, I18NSentence.value, I18NParagraph.value) AS value,
 ContentElement.format,
 ContentEdition.stop,
 ContentEdition.created
FROM ContentEdition
JOIN ContentElement ON ContentElement.edition = ContentEdition.id
LEFT JOIN I18NWord ON I18NWord.id = ContentElement.word
LEFT JOIN I18NSentence ON I18NSentence.id = ContentElement.sentence
LEFT JOIN I18NParagraph ON I18NParagraph.id = ContentElement.paragraph;

DROP VIEW IF EXISTS ContentSites;
CREATE VIEW ContentSites AS
SELECT site, content, sequence, created
FROM ContentSite
WHERE stop IS NULL;

DROP VIEW IF EXISTS ContentLists;
CREATE VIEW ContentLists AS
SELECT ContentList.listName,
 Name.value AS listNameValue,
 ContentList.content,
 ContentList.sequence,
 ContentList.created
FROM ContentList
LEFT JOIN I18NWord AS Name ON Name.id = ContentList.listName
WHERE ContentList.stop IS NULL;

DROP VIEW IF EXISTS CampaignContents;
CREATE VIEW CampaignContents AS
SELECT campaign, content, sequence, created
FROM CampaignContent
WHERE stop IS NULL;

DROP VIEW IF EXISTS CampaignAttachments;
CREATE VIEW CampaignAttachments AS
SELECT CampaignAttachment.campaign,
 CampaignAttachment.path,
 CampaignAttachment.sequence,
 Type.value AS type,
 Target.value AS target,
 CampaignAttachment.created
FROM CampaignAttachment
LEFT JOIN I18NWord AS Type ON Type.id = CampaignAttachment.type
LEFT JOIN I18NWord AS Target ON Target.id = CampaignAttachment.target
WHERE CampaignAttachment.stop IS NULL;

DROP VIEW IF EXISTS CampaignRuns;
CREATE VIEW CampaignRuns AS
SELECT id AS run, campaign, started, stop, created
FROM CampaignRun;

DROP VIEW IF EXISTS CampaignEvents;
CREATE VIEW CampaignEvents AS
SELECT CampaignEvent.campaign,
 CampaignEvent.individual,
 Kind.value AS kind,
 CampaignEvent.path,
 CampaignEvent.run,
 CampaignEvent.created
FROM CampaignEvent
LEFT JOIN I18NWord AS Kind ON Kind.id = CampaignEvent.kind;

DROP VIEW IF EXISTS CampaignRecipients;
CREATE VIEW CampaignRecipients AS
SELECT Campaign.id AS campaign,
 ListIndividual.individual,
 EmailAddress.value AS email,
 IndividualAddress.address
FROM Campaign
JOIN ListIndividualName ON ListIndividualName.name = Campaign.listName
 AND (Campaign.listSet IS NULL OR ListIndividualName.listSet = Campaign.listSet)
JOIN ListIndividual ON ListIndividual.id = ListIndividualName.listIndividual
 AND ListIndividual.unlist IS NULL
LEFT JOIN IndividualEmail ON IndividualEmail.individual = ListIndividual.individual
 AND IndividualEmail.stop IS NULL
 AND IndividualEmail.type IS NULL
LEFT JOIN EmailAddress ON EmailAddress.email = IndividualEmail.email
LEFT JOIN IndividualAddress ON IndividualAddress.individual = ListIndividual.individual
 AND IndividualAddress.stop IS NULL
 AND IndividualAddress.type IS NULL;

ALTER TABLE Session ADD COLUMN culture smallint;

DROP VIEW IF EXISTS ContentCultures;
CREATE VIEW ContentCultures AS
WITH open_edition AS (
 SELECT id, content
 FROM ContentEdition
 WHERE stop IS NULL
),
elem AS (
 SELECT open_edition.content, ContentElement.word, ContentElement.sentence, ContentElement.paragraph
 FROM open_edition
 JOIN ContentElement ON ContentElement.edition = open_edition.id
),
candidate AS (
 SELECT elem.content, Word.culture
 FROM elem
 JOIN Word ON Word.id = elem.word
 UNION
 SELECT elem.content, WordPlural.culture
 FROM elem
 JOIN WordPlural ON WordPlural.word = elem.word
 UNION
 SELECT elem.content, Sentence.culture
 FROM elem
 JOIN Sentence ON Sentence.id = elem.sentence
 UNION
 SELECT elem.content, Paragraph.culture
 FROM elem
 JOIN Paragraph ON Paragraph.id = elem.paragraph
 UNION
 SELECT content, 1033
 FROM open_edition
)
SELECT candidate.content,
 candidate.culture,
 Culture.name
FROM candidate
JOIN Culture ON Culture.code = candidate.culture
WHERE NOT EXISTS (
 SELECT 1
 FROM elem
 WHERE elem.content = candidate.content
 AND (
  (elem.word IS NOT NULL AND NOT (
    EXISTS (SELECT 1 FROM Word WHERE Word.id = elem.word AND Word.culture = candidate.culture)
    OR EXISTS (SELECT 1 FROM WordPlural WHERE WordPlural.word = elem.word AND WordPlural.culture = candidate.culture)
  ))
  OR (elem.sentence IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM Sentence WHERE Sentence.id = elem.sentence AND Sentence.culture = candidate.culture
  ))
  OR (elem.paragraph IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM Paragraph WHERE Paragraph.id = elem.paragraph AND Paragraph.culture = candidate.culture
  ))
 )
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
LEFT JOIN I18NWord AS Type ON Type.id = SessionToken.type
LEFT JOIN SiteApplicationRelease ON SiteApplicationRelease.id = SessionToken.siteApplicationRelease
LEFT JOIN Site ON Site.id = SiteApplicationRelease.site
LEFT JOIN I18NSentence AS SiteName ON SiteName.id = Site.name
LEFT JOIN People ON People.individual = bound.individual
LEFT JOIN Entities ON Entities.individual = bound.individual
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email;


INSERT INTO Word (id,culture,value) SELECT 80110,1033,'subscription' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80110 AND culture=1033);
INSERT INTO Word (id,culture,value) SELECT 80110,1036,'abonnement' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80110 AND culture=1036);
INSERT INTO Word (id,culture,value) SELECT 80110,1045,'subskrypcja' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80110 AND culture=1045);
INSERT INTO Word (id,culture,value) SELECT 80110,2058,'suscripción' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80110 AND culture=2058);
INSERT INTO Word (id,culture,value) SELECT 80111,1033,'subscriptions' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80111 AND culture=1033);
INSERT INTO Word (id,culture,value) SELECT 80111,1036,'abonnements' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80111 AND culture=1036);
INSERT INTO Word (id,culture,value) SELECT 80111,1045,'subskrypcje' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80111 AND culture=1045);
INSERT INTO Word (id,culture,value) SELECT 80111,2058,'suscripciones' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80111 AND culture=2058);
INSERT INTO Word (id,culture,value) SELECT 80112,1045,'subskrypcji' WHERE NOT EXISTS (SELECT 1 FROM Word WHERE id=80112 AND culture=1045);
INSERT INTO Sentence (id,culture,value,length) SELECT 80110,1033,'Thank you for your',18 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80110 AND culture=1033);
INSERT INTO Sentence (id,culture,value,length) SELECT 80110,1036,'Merci pour votre',16 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80110 AND culture=1036);
INSERT INTO Sentence (id,culture,value,length) SELECT 80110,1045,'Dziękuję za Twoją',17 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80110 AND culture=1045);
INSERT INTO Sentence (id,culture,value,length) SELECT 80110,2058,'Gracias por tu',14 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80110 AND culture=2058);
INSERT INTO Sentence (id,culture,value,length) SELECT 80130,1033,'Thank you',9 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80130 AND culture=1033);
INSERT INTO Sentence (id,culture,value,length) SELECT 80130,1036,'Merci',5 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80130 AND culture=1036);
INSERT INTO Sentence (id,culture,value,length) SELECT 80130,1045,'Dziękuję',8 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80130 AND culture=1045);
INSERT INTO Sentence (id,culture,value,length) SELECT 80130,2058,'Gracias',7 WHERE NOT EXISTS (SELECT 1 FROM Sentence WHERE id=80130 AND culture=2058);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 50, 1033, 80110, 0, 80111 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=50);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 51, 1033, 80110, 3, 80111 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=51);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 52, 1036, 80110, 0, 80110 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=52);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 53, 1036, 80110, 3, 80111 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=53);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 54, 1045, 80110, 0, 80110 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=54);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 55, 1045, 80110, 3, 80111 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=55);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 56, 1045, 80110, 4, 80112 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=56);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 57, 2058, 80110, 0, 80111 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=57);
INSERT INTO WordPlural (id, culture, word, plural, form) SELECT 58, 2058, 80110, 3, 80111 WHERE NOT EXISTS (SELECT 1 FROM WordPlural WHERE id=58);
INSERT INTO Content (id, name) SELECT 10, 80130 WHERE NOT EXISTS (SELECT 1 FROM Content WHERE id=10);
INSERT INTO ContentEdition (id, content) SELECT 10, 10 WHERE NOT EXISTS (SELECT 1 FROM ContentEdition WHERE id=10);
INSERT INTO ContentElement (edition, sequence, sentence) SELECT 10, 1, 80110 WHERE NOT EXISTS (SELECT 1 FROM ContentElement WHERE edition=10 AND sequence=1);
INSERT INTO ContentElement (edition, sequence, word, argument) SELECT 10, 2, 80110, 80111 WHERE NOT EXISTS (SELECT 1 FROM ContentElement WHERE edition=10 AND sequence=2);

