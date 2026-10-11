-- =============================================================================
-- Business schema upgrade: 0.2.14 -> 0.2.15 (PostgreSQL)
-- =============================================================================
--
-- Living upgrade path while 0.2.15 is unreleased. A database installed at
-- 0.2.14 reaches the GetSite lookup below.
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Active SchemaVersion is Business 0.2.14 (stop IS NULL)
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.14-0.2.15.sql
--
-- The script is one transaction. A failed statement rolls the function back.
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.14 database)
-- ---------------------------------------------------------------------------
--
--  1) GetSite returns an existing site whose name is the sentence id, or a
--     Word id with the same text. It does not rewrite Site.name and it does
--     not insert a second site for that name.
--  2) ContentElement.name and ContentElement.type are integer columns.
--     Each is a GetIdentifier id (Word.culture is null). They are set
--     together, and only when word, sentence, and paragraph are all null.
--  3) SetContentElement stores those identifiers on that write.
--     SetFormatAttribute and StopFormatAttribute store name, value, and
--     target with GetIdentifier. argument on a word stays GetWord.
--  4) ContentElements and ContentHistory return kind dynamic, plus
--     identifier and identifierType from Word where culture is null.
--     FormatAttributes and FormatFor read name, value, and target the
--     same way. ContentBody, SiteContent, and ListContent take
--     Culture.name. The two-argument calls use ClientCulture().
--  5) Notice sentences gain es-MX text on the same ids as en-US, when
--     those English sentences are already stored.
--  6) ContentElement.squash is a nullable integer. Null means the element
--     renders alone. The 10-argument SetContentElement stores GetIdentifier
--     of inSquash when that string is set. The shorter forms pass null.
--     ContentElements, ContentHistory, ContentBody, SiteContent, and
--     ListContent return that culture-null word. Null stays null.
--
-- Version stamp stays commented until 0.2.15 is released.
--
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

SET search_path TO business, public;

DO $$
BEGIN
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
   AND patch.value = '14'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.14';
 END IF;
END $$;

ALTER TABLE contentelement ADD COLUMN IF NOT EXISTS name integer;
ALTER TABLE contentelement ADD COLUMN IF NOT EXISTS type integer;
ALTER TABLE contentelement ADD COLUMN IF NOT EXISTS squash integer;

CREATE OR REPLACE FUNCTION GetSite (
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 site_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  SELECT id INTO site_id
  FROM Site
  WHERE name = name_id
  LIMIT 1;
  IF site_id IS NULL THEN
   SELECT Site.id INTO site_id
   FROM Site
   JOIN Word ON Word.id = Site.name
   WHERE Word.value = inName
   ORDER BY Site.id
   LIMIT 1;
  END IF;
  IF site_id IS NULL THEN
   PERFORM pg_advisory_lock(name_id);
   BEGIN
   INSERT INTO Site (name) (
    SELECT name_id AS name
    FROM Dual
    LEFT JOIN Site AS exists ON exists.name = name_id
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(name_id);
     RAISE;
   END;
   SELECT id INTO site_id
   FROM Site
   WHERE name = name_id
   LIMIT 1;
  END IF;
 END IF;
 RETURN site_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetFormatAttribute (
 inFormat integer,
 inName varchar,
 inValue varchar,
 inTarget varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 value_id integer;
 target_id integer;
BEGIN
 IF inFormat IS NOT NULL AND inName IS NOT NULL THEN
  name_id := (SELECT GetIdentifier(inName));
  value_id := (SELECT GetIdentifier(inValue));
  target_id := (SELECT GetIdentifier(inTarget));
  PERFORM pg_advisory_lock(inFormat);
  BEGIN
   INSERT INTO FormatAttribute (format, name, value, target) (
    SELECT inFormat, name_id, value_id, target_id
    FROM Dual
    LEFT JOIN FormatAttribute AS exists ON exists.format = inFormat
     AND exists.name = name_id
     AND ((exists.value = value_id) OR (exists.value IS NULL AND value_id IS NULL))
     AND ((exists.target = target_id) OR (exists.target IS NULL AND target_id IS NULL))
     AND exists.stop IS NULL
    WHERE exists.format IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inFormat);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inFormat);
    RAISE;
  END;
 END IF;
 RETURN inFormat;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopFormatAttribute (
 inFormat integer,
 inName varchar,
 inValue varchar,
 inTarget varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 value_id integer;
 target_id integer;
BEGIN
 IF inFormat IS NOT NULL AND inName IS NOT NULL THEN
  name_id := (SELECT GetIdentifier(inName));
  value_id := (SELECT GetIdentifier(inValue));
  target_id := (SELECT GetIdentifier(inTarget));
  PERFORM pg_advisory_lock(inFormat);
  BEGIN
   UPDATE FormatAttribute
   SET stop = NOW()
   WHERE format = inFormat
    AND name = name_id
    AND ((value = value_id) OR (value IS NULL AND value_id IS NULL))
    AND ((target = target_id) OR (target IS NULL AND target_id IS NULL))
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(inFormat);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inFormat);
    RAISE;
  END;
 END IF;
 RETURN inFormat;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentElement (
 inContent integer,
 inSequence integer,
 inFormat integer,
 inWord integer,
 inSentence integer,
 inParagraph integer,
 inArgument varchar,
 inName varchar,
 inType varchar,
 inSquash varchar
) RETURNS integer AS $$
DECLARE
 edition_id integer;
 atom_count integer;
 argument_id integer;
 name_id integer;
 type_id integer;
 squash_id integer;
 dynamic boolean;
BEGIN
 atom_count := (inWord IS NOT NULL)::integer
  + (inSentence IS NOT NULL)::integer
  + (inParagraph IS NOT NULL)::integer;
 dynamic := atom_count = 0
  AND inName IS NOT NULL
  AND inType IS NOT NULL;
 IF dynamic THEN
  name_id := (SELECT GetIdentifier(inName));
  type_id := (SELECT GetIdentifier(inType));
 ELSIF atom_count = 1 AND inWord IS NOT NULL THEN
  argument_id := (SELECT GetWord(inArgument));
 END IF;
 IF inContent IS NOT NULL
  AND inSequence IS NOT NULL
  AND (
   (atom_count = 1 AND inName IS NULL AND inType IS NULL)
   OR (dynamic AND name_id IS NOT NULL AND type_id IS NOT NULL)
  ) THEN
  IF inSquash IS NOT NULL AND inSquash <> '' THEN
   squash_id := (SELECT GetIdentifier(inSquash));
  END IF;
  PERFORM pg_advisory_lock(inContent);
  BEGIN
   SELECT id INTO edition_id
   FROM ContentEdition
   WHERE content = inContent
    AND stop IS NULL
   LIMIT 1;
   IF edition_id IS NULL THEN
    INSERT INTO ContentEdition (content) (
     SELECT inContent
     FROM Dual
     LEFT JOIN ContentEdition AS exists ON exists.content = inContent
      AND exists.stop IS NULL
     WHERE exists.id IS NULL
     LIMIT 1
    );
    SELECT id INTO edition_id
    FROM ContentEdition
    WHERE content = inContent
     AND stop IS NULL
    LIMIT 1;
   END IF;
   INSERT INTO ContentElement (
    edition, sequence, word, sentence, paragraph, format, argument, name, type, squash
   ) (
    SELECT edition_id, inSequence, inWord, inSentence, inParagraph,
     inFormat, argument_id, name_id, type_id, squash_id
    FROM Dual
    LEFT JOIN ContentElement AS exists ON exists.edition = edition_id
     AND exists.sequence = inSequence
    WHERE exists.edition IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inContent);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inContent);
    RAISE;
  END;
 END IF;
 RETURN inContent;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentElement (
 inContent integer,
 inSequence integer,
 inFormat integer,
 inWord integer,
 inSentence integer,
 inParagraph integer,
 inArgument varchar,
 inName varchar,
 inType varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetContentElement(
  inContent, inSequence, inFormat, inWord, inSentence, inParagraph,
  inArgument, inName, inType, NULL
 ));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentElement (
 inContent integer,
 inSequence integer,
 inFormat integer,
 inWord integer,
 inSentence integer,
 inParagraph integer,
 inArgument varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetContentElement(
  inContent, inSequence, inFormat, inWord, inSentence, inParagraph, inArgument, NULL, NULL
 ));
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS SiteContent(integer, varchar);
DROP FUNCTION IF EXISTS ListContent(varchar, varchar);
DROP FUNCTION IF EXISTS ContentBody(integer, varchar);
DROP FUNCTION IF EXISTS SiteContent(integer, varchar, varchar);
DROP FUNCTION IF EXISTS ListContent(varchar, varchar, varchar);
DROP FUNCTION IF EXISTS ContentBody(integer, varchar, varchar);

-- FormatFor(format integer, target varchar).
-- A row whose target word matches inTarget wins over a null target of the same name.
CREATE OR REPLACE FUNCTION FormatFor (
 inFormat integer,
 inTarget varchar
) RETURNS TABLE (
 name varchar,
 value varchar
) AS $$
BEGIN
 IF inFormat IS NULL THEN
  RETURN;
 END IF;
 RETURN QUERY
 SELECT AttrName.value,
  AttrValue.value
 FROM FormatAttribute
 JOIN Word AS AttrName ON AttrName.id = FormatAttribute.name AND AttrName.culture IS NULL
 LEFT JOIN Word AS AttrValue ON AttrValue.id = FormatAttribute.value AND AttrValue.culture IS NULL
 LEFT JOIN Word AS AttrTarget ON AttrTarget.id = FormatAttribute.target AND AttrTarget.culture IS NULL
 WHERE FormatAttribute.format = inFormat
  AND FormatAttribute.stop IS NULL
  AND (
   (
    inTarget IS NOT NULL
    AND FormatAttribute.target IS NOT NULL
    AND UPPER(AttrTarget.value) = UPPER(inTarget)
   )
   OR (
    FormatAttribute.target IS NULL
    AND (
     inTarget IS NULL
     OR NOT EXISTS (
      SELECT 1
      FROM FormatAttribute AS specific
      JOIN Word AS SpecificTarget ON SpecificTarget.id = specific.target AND SpecificTarget.culture IS NULL
      WHERE specific.format = FormatAttribute.format
       AND specific.name = FormatAttribute.name
       AND specific.stop IS NULL
       AND specific.target IS NOT NULL
       AND UPPER(SpecificTarget.value) = UPPER(inTarget)
     )
    )
   )
  );
END;
$$ LANGUAGE plpgsql;

-- ContentBody(content integer, target varchar, culture varchar).
-- culture is Culture.name. NULL or an unknown name uses 1033.
-- A missing translation uses the 1033 text of the same element id.
-- Does not set the connection culture and does not write.
CREATE OR REPLACE FUNCTION ContentBody (
 inContent integer,
 inTarget varchar,
 inCulture varchar
) RETURNS TABLE (
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar,
 identifier varchar,
 identifierType varchar,
 squash varchar
) AS $$
DECLARE
 culture_code integer;
BEGIN
 SELECT Culture.code INTO culture_code
 FROM Culture
 WHERE UPPER(Culture.name) = UPPER(inCulture)
 LIMIT 1;
 IF culture_code IS NULL THEN
  culture_code := 1033;
 END IF;
 RETURN QUERY
 SELECT ContentElement.sequence,
  CASE
   WHEN ContentElement.word IS NOT NULL THEN 'word'
   WHEN ContentElement.sentence IS NOT NULL THEN 'sentence'
   WHEN ContentElement.paragraph IS NOT NULL THEN 'paragraph'
   WHEN ContentElement.name IS NOT NULL AND ContentElement.type IS NOT NULL THEN 'dynamic'
   ELSE NULL
  END::varchar,
  COALESCE(ContentElement.word, ContentElement.sentence, ContentElement.paragraph),
  CASE
   WHEN ContentElement.word IS NOT NULL THEN COALESCE(WordTr.value, WordDef.value)
   WHEN ContentElement.sentence IS NOT NULL THEN COALESCE(SentenceTr.value, SentenceDef.value)
   WHEN ContentElement.paragraph IS NOT NULL THEN COALESCE(ParagraphTr.value, ParagraphDef.value)
   ELSE NULL
  END::varchar,
  ContentElement.format,
  COALESCE(ArgumentTr.value, ArgumentDef.value)::varchar,
  winning.name,
  winning.attribute,
  IdentName.value::varchar,
  IdentType.value::varchar,
  SquashWord.value::varchar
 FROM ContentEdition
 JOIN ContentElement ON ContentElement.edition = ContentEdition.id
 LEFT JOIN Word AS WordDef ON WordDef.id = ContentElement.word AND WordDef.culture = 1033
 LEFT JOIN Word AS WordTr ON WordTr.id = ContentElement.word AND WordTr.culture = culture_code
 LEFT JOIN Sentence AS SentenceDef ON SentenceDef.id = ContentElement.sentence AND SentenceDef.culture = 1033
 LEFT JOIN Sentence AS SentenceTr ON SentenceTr.id = ContentElement.sentence AND SentenceTr.culture = culture_code
 LEFT JOIN Paragraph AS ParagraphDef ON ParagraphDef.id = ContentElement.paragraph AND ParagraphDef.culture = 1033
 LEFT JOIN Paragraph AS ParagraphTr ON ParagraphTr.id = ContentElement.paragraph AND ParagraphTr.culture = culture_code
 LEFT JOIN Word AS ArgumentDef ON ArgumentDef.id = ContentElement.argument AND ArgumentDef.culture = 1033
 LEFT JOIN Word AS ArgumentTr ON ArgumentTr.id = ContentElement.argument AND ArgumentTr.culture = culture_code
 LEFT JOIN Word AS IdentName ON IdentName.id = ContentElement.name AND IdentName.culture IS NULL
 LEFT JOIN Word AS IdentType ON IdentType.id = ContentElement.type AND IdentType.culture IS NULL
 LEFT JOIN Word AS SquashWord ON SquashWord.id = ContentElement.squash AND SquashWord.culture IS NULL
 LEFT JOIN LATERAL (
  SELECT FormatFor.name,
   FormatFor.value AS attribute
  FROM FormatFor(ContentElement.format, inTarget)
 ) AS winning ON true
 WHERE ContentEdition.content = inContent
  AND ContentEdition.stop IS NULL
 ORDER BY ContentElement.sequence, winning.name;
END;
$$ LANGUAGE plpgsql;

-- ContentBody(content integer, target varchar).
-- Uses ClientCulture(). Does not write.
CREATE OR REPLACE FUNCTION ContentBody (
 inContent integer,
 inTarget varchar
) RETURNS TABLE (
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar,
 identifier varchar,
 identifierType varchar,
 squash varchar
) AS $$
BEGIN
 RETURN QUERY
 SELECT body.sequence, body.kind, body.element, body.value, body.format,
  body.argument, body.name, body.attribute, body.identifier, body.identifierType, body.squash
 FROM ContentBody(inContent, inTarget, (
  SELECT Culture.name FROM Culture WHERE Culture.code = ClientCulture() LIMIT 1
 )) AS body;
END;
$$ LANGUAGE plpgsql;

-- SiteContent(site integer, target varchar, culture varchar).
-- Unstopped ContentSite rows, placement sequence then element sequence.
-- Does not set the connection culture and does not write.
CREATE OR REPLACE FUNCTION SiteContent (
 inSite integer,
 inTarget varchar,
 inCulture varchar
) RETURNS TABLE (
 place integer,
 content integer,
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar,
 identifier varchar,
 identifierType varchar,
 squash varchar
) AS $$
BEGIN
 RETURN QUERY
 SELECT ContentSites.sequence,
  ContentSites.content,
  body.sequence,
  body.kind,
  body.element,
  body.value,
  body.format,
  body.argument,
  body.name,
  body.attribute,
  body.identifier,
  body.identifierType, body.squash
 FROM ContentSites
 JOIN LATERAL ContentBody(ContentSites.content, inTarget, inCulture) AS body ON true
 WHERE ContentSites.site = inSite
 ORDER BY ContentSites.sequence, body.sequence, body.name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SiteContent (
 inSite integer,
 inTarget varchar
) RETURNS TABLE (
 place integer,
 content integer,
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar,
 identifier varchar,
 identifierType varchar,
 squash varchar
) AS $$
BEGIN
 RETURN QUERY
 SELECT body.place, body.content, body.sequence, body.kind, body.element,
  body.value, body.format, body.argument, body.name, body.attribute,
  body.identifier, body.identifierType, body.squash
 FROM SiteContent(inSite, inTarget, (
  SELECT Culture.name FROM Culture WHERE Culture.code = ClientCulture() LIMIT 1
 )) AS body;
END;
$$ LANGUAGE plpgsql;

-- ListContent(list name varchar, target varchar, culture varchar).
-- Unstopped ContentList rows for that list name. Does not create the word.
-- Does not set the connection culture and does not write.
CREATE OR REPLACE FUNCTION ListContent (
 inListName varchar,
 inTarget varchar,
 inCulture varchar
) RETURNS TABLE (
 place integer,
 content integer,
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar,
 identifier varchar,
 identifierType varchar,
 squash varchar
) AS $$
DECLARE
 list_id integer;
BEGIN
 IF inListName IS NULL THEN
  RETURN;
 END IF;
 SELECT Word.id INTO list_id
 FROM Word
 WHERE Word.culture = 1033
  AND UPPER(Word.value) = UPPER(inListName)
 LIMIT 1;
 IF list_id IS NULL THEN
  RETURN;
 END IF;
 RETURN QUERY
 SELECT ContentList.sequence,
  ContentList.content,
  body.sequence,
  body.kind,
  body.element,
  body.value,
  body.format,
  body.argument,
  body.name,
  body.attribute,
  body.identifier,
  body.identifierType, body.squash
 FROM ContentList
 JOIN LATERAL ContentBody(ContentList.content, inTarget, inCulture) AS body ON true
 WHERE ContentList.listName = list_id
  AND ContentList.stop IS NULL
 ORDER BY ContentList.sequence, body.sequence, body.name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListContent (
 inListName varchar,
 inTarget varchar
) RETURNS TABLE (
 place integer,
 content integer,
 sequence integer,
 kind varchar,
 element integer,
 value varchar,
 format integer,
 argument varchar,
 name varchar,
 attribute varchar,
 identifier varchar,
 identifierType varchar,
 squash varchar
) AS $$
BEGIN
 RETURN QUERY
 SELECT body.place, body.content, body.sequence, body.kind, body.element,
  body.value, body.format, body.argument, body.name, body.attribute,
  body.identifier, body.identifierType, body.squash
 FROM ListContent(inListName, inTarget, (
  SELECT Culture.name FROM Culture WHERE Culture.code = ClientCulture() LIMIT 1
 )) AS body;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW FormatAttributes AS
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

CREATE OR REPLACE VIEW ContentElements AS
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

CREATE OR REPLACE VIEW ContentElementAttributes AS
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

CREATE OR REPLACE VIEW ContentHistory AS
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

-- es-MX for the notice sentences, on the same ids as en-US and fr-FR.
INSERT INTO Sentence (id, culture, value, length)
SELECT s.id, 2058, 'Aquí está el aviso', char_length('Aquí está el aviso')
FROM Sentence AS s
WHERE s.culture = 1033
 AND s.value = 'Here is the notice'
 AND NOT EXISTS (
  SELECT 1 FROM Sentence AS t WHERE t.id = s.id AND t.culture = 2058
 );
INSERT INTO Sentence (id, culture, value, length)
SELECT s.id, 2058, 'Artículos listos', char_length('Artículos listos')
FROM Sentence AS s
WHERE s.culture = 1033
 AND s.value = 'Items ready'
 AND NOT EXISTS (
  SELECT 1 FROM Sentence AS t WHERE t.id = s.id AND t.culture = 2058
 );

-- Mark schema upgraded to 0.2.15 when the hop body is ready for the release.
-- SELECT SetSchemaVersion('Business', '0', '2', '15');

COMMIT;
