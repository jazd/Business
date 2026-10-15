-- Content — format groups, editions, site and list placement (diagram: content)

CREATE OR REPLACE FUNCTION SetFormat (
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 format_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  PERFORM pg_advisory_lock(name_id);
  BEGIN
   SELECT id INTO format_id
   FROM Format
   WHERE name = name_id
   LIMIT 1;
   IF format_id IS NULL THEN
    INSERT INTO Format (name) (
     SELECT name_id
     FROM Dual
     LEFT JOIN Format AS exists ON exists.name = name_id
     WHERE exists.id IS NULL
     LIMIT 1
    );
    SELECT id INTO format_id
    FROM Format
    WHERE name = name_id
    LIMIT 1;
   END IF;
   PERFORM pg_advisory_unlock(name_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(name_id);
    RAISE;
  END;
 END IF;
 RETURN format_id;
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

CREATE OR REPLACE FUNCTION SetContent (
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 content_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  PERFORM pg_advisory_lock(name_id);
  BEGIN
   SELECT id INTO content_id
   FROM Content
   WHERE name = name_id
   LIMIT 1;
   IF content_id IS NULL THEN
    INSERT INTO Content (name) (
     SELECT name_id
     FROM Dual
     LEFT JOIN Content AS exists ON exists.name = name_id
     WHERE exists.id IS NULL
     LIMIT 1
    );
    SELECT id INTO content_id
    FROM Content
    WHERE name = name_id
    LIMIT 1;
   END IF;
   PERFORM pg_advisory_unlock(name_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(name_id);
    RAISE;
  END;
 END IF;
 RETURN content_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopContent (
 inContent integer
) RETURNS integer AS $$
BEGIN
 IF inContent IS NOT NULL THEN
  PERFORM pg_advisory_lock(inContent);
  BEGIN
   UPDATE ContentEdition
   SET stop = NOW()
   WHERE content = inContent
    AND stop IS NULL;
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

CREATE OR REPLACE FUNCTION SetContentElement (
 inContent integer,
 inSequence integer,
 inFormat integer,
 inWord integer,
 inSentence integer,
 inParagraph integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetContentElement(inContent, inSequence, inFormat, inWord, inSentence, inParagraph, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentSite (
 inSite integer,
 inContent integer,
 inSequence integer
) RETURNS integer AS $$
DECLARE
 place integer;
BEGIN
 IF inSite IS NOT NULL AND inContent IS NOT NULL THEN
  place := inSequence;
  IF place IS NULL THEN
   place := (
    SELECT COALESCE(MAX(sequence), 0) + 1
    FROM ContentSite
    WHERE site = inSite
     AND stop IS NULL
   );
  END IF;
  PERFORM pg_advisory_lock(inSite);
  BEGIN
   INSERT INTO ContentSite (content, site, sequence) (
    SELECT inContent, inSite, place
    FROM Dual
    LEFT JOIN ContentSite AS exists ON exists.site = inSite
     AND exists.content = inContent
     AND exists.stop IS NULL
    WHERE exists.content IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inSite);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inSite);
    RAISE;
  END;
 END IF;
 RETURN inContent;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentSite (
 inSite integer,
 inContent integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetContentSite(inSite, inContent, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopContentSite (
 inSite integer,
 inContent integer
) RETURNS integer AS $$
BEGIN
 IF inSite IS NOT NULL AND inContent IS NOT NULL THEN
  PERFORM pg_advisory_lock(inSite);
  BEGIN
   UPDATE ContentSite
   SET stop = NOW()
   WHERE site = inSite
    AND content = inContent
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(inSite);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inSite);
    RAISE;
  END;
 END IF;
 RETURN inContent;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentList (
 inListName varchar,
 inContent integer,
 inSequence integer
) RETURNS integer AS $$
DECLARE
 list_id integer;
 place integer;
BEGIN
 IF inListName IS NOT NULL AND inContent IS NOT NULL THEN
  list_id := (SELECT GetWord(inListName));
  place := inSequence;
  IF place IS NULL THEN
   place := (
    SELECT COALESCE(MAX(sequence), 0) + 1
    FROM ContentList
    WHERE listName = list_id
     AND stop IS NULL
   );
  END IF;
  PERFORM pg_advisory_lock(list_id);
  BEGIN
   INSERT INTO ContentList (content, listName, sequence) (
    SELECT inContent, list_id, place
    FROM Dual
    LEFT JOIN ContentList AS exists ON exists.listName = list_id
     AND exists.content = inContent
     AND exists.stop IS NULL
    WHERE exists.content IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(list_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(list_id);
    RAISE;
  END;
 END IF;
 RETURN inContent;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetContentList (
 inListName varchar,
 inContent integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetContentList(inListName, inContent, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopContentList (
 inListName varchar,
 inContent integer
) RETURNS integer AS $$
DECLARE
 list_id integer;
BEGIN
 IF inListName IS NOT NULL AND inContent IS NOT NULL THEN
  list_id := (SELECT GetWord(inListName));
  PERFORM pg_advisory_lock(list_id);
  BEGIN
   UPDATE ContentList
   SET stop = NOW()
   WHERE listName = list_id
    AND content = inContent
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(list_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(list_id);
    RAISE;
  END;
 END IF;
 RETURN inContent;
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION SetCampaign (
 inName varchar,
 inListName varchar,
 inListSet varchar,
 inChannel varchar,
 inPeriod integer
) RETURNS integer AS $$
DECLARE
 name_id integer;
 list_id integer;
 set_id integer;
 channel_id integer;
 campaign_id integer;
BEGIN
 IF inName IS NOT NULL AND inListName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  list_id := (SELECT GetWord(inListName));
  set_id := (SELECT GetWord(inListSet));
  channel_id := (SELECT GetIdentifier(inChannel));
  PERFORM pg_advisory_lock(name_id);
  BEGIN
   SELECT id INTO campaign_id
   FROM Campaign
   WHERE name = name_id
   LIMIT 1;
   IF campaign_id IS NULL THEN
    INSERT INTO Campaign (name, listName, listSet, channel, period) (
     SELECT name_id, list_id, set_id, channel_id, inPeriod
     FROM Dual
     LEFT JOIN Campaign AS exists ON exists.name = name_id
     WHERE exists.id IS NULL
     LIMIT 1
    );
    SELECT id INTO campaign_id
    FROM Campaign
    WHERE name = name_id
    LIMIT 1;
   END IF;
   PERFORM pg_advisory_unlock(name_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(name_id);
    RAISE;
  END;
 END IF;
 RETURN campaign_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetCampaign (
 inName varchar,
 inListName varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetCampaign(inName, inListName, NULL, NULL, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StartCampaign (
 inCampaign integer
) RETURNS integer AS $$
BEGIN
 IF inCampaign IS NOT NULL THEN
  PERFORM pg_advisory_lock(inCampaign);
  BEGIN
   INSERT INTO CampaignRun (campaign) (
    SELECT inCampaign
    FROM Dual
    LEFT JOIN CampaignRun AS exists ON exists.campaign = inCampaign
     AND exists.stop IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inCampaign);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inCampaign);
    RAISE;
  END;
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopCampaign (
 inCampaign integer
) RETURNS integer AS $$
BEGIN
 IF inCampaign IS NOT NULL THEN
  PERFORM pg_advisory_lock(inCampaign);
  BEGIN
   UPDATE CampaignRun
   SET stop = NOW()
   WHERE campaign = inCampaign
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(inCampaign);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inCampaign);
    RAISE;
  END;
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetCampaignContent (
 inCampaign integer,
 inContent integer,
 inSequence integer
) RETURNS integer AS $$
DECLARE
 place integer;
BEGIN
 IF inCampaign IS NOT NULL AND inContent IS NOT NULL THEN
  place := inSequence;
  IF place IS NULL THEN
   place := (
    SELECT COALESCE(MAX(sequence), 0) + 1
    FROM CampaignContent
    WHERE campaign = inCampaign
     AND stop IS NULL
   );
  END IF;
  PERFORM pg_advisory_lock(inCampaign);
  BEGIN
   INSERT INTO CampaignContent (campaign, content, sequence) (
    SELECT inCampaign, inContent, place
    FROM Dual
    LEFT JOIN CampaignContent AS exists ON exists.campaign = inCampaign
     AND exists.content = inContent
     AND exists.stop IS NULL
    WHERE exists.content IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inCampaign);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inCampaign);
    RAISE;
  END;
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetCampaignContent (
 inCampaign integer,
 inContent integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetCampaignContent(inCampaign, inContent, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopCampaignContent (
 inCampaign integer,
 inContent integer
) RETURNS integer AS $$
BEGIN
 IF inCampaign IS NOT NULL AND inContent IS NOT NULL THEN
  PERFORM pg_advisory_lock(inCampaign);
  BEGIN
   UPDATE CampaignContent
   SET stop = NOW()
   WHERE campaign = inCampaign
    AND content = inContent
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(inCampaign);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inCampaign);
    RAISE;
  END;
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetCampaignAttachment (
 inCampaign integer,
 inPath bigint,
 inSequence integer,
 inType varchar,
 inTarget varchar
) RETURNS integer AS $$
DECLARE
 place integer;
 type_id integer;
 target_id integer;
BEGIN
 IF inCampaign IS NOT NULL AND inPath IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  target_id := (SELECT GetWord(inTarget));
  place := inSequence;
  IF place IS NULL THEN
   place := (
    SELECT COALESCE(MAX(sequence), 0) + 1
    FROM CampaignAttachment
    WHERE campaign = inCampaign
     AND stop IS NULL
   );
  END IF;
  PERFORM pg_advisory_lock(inCampaign);
  BEGIN
   INSERT INTO CampaignAttachment (campaign, path, sequence, type, target) (
    SELECT inCampaign, inPath, place, type_id, target_id
    FROM Dual
    LEFT JOIN CampaignAttachment AS exists ON exists.campaign = inCampaign
     AND exists.path = inPath
     AND ((exists.type = type_id) OR (exists.type IS NULL AND type_id IS NULL))
     AND ((exists.target = target_id) OR (exists.target IS NULL AND target_id IS NULL))
     AND exists.stop IS NULL
    WHERE exists.path IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inCampaign);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inCampaign);
    RAISE;
  END;
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetCampaignAttachment (
 inCampaign integer,
 inPath bigint,
 inType varchar,
 inTarget varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT SetCampaignAttachment(inCampaign, inPath, NULL, inType, inTarget));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION StopCampaignAttachment (
 inCampaign integer,
 inPath bigint,
 inType varchar,
 inTarget varchar
) RETURNS integer AS $$
DECLARE
 type_id integer;
 target_id integer;
BEGIN
 IF inCampaign IS NOT NULL AND inPath IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  target_id := (SELECT GetWord(inTarget));
  PERFORM pg_advisory_lock(inCampaign);
  BEGIN
   UPDATE CampaignAttachment
   SET stop = NOW()
   WHERE campaign = inCampaign
    AND path = inPath
    AND ((type = type_id) OR (type IS NULL AND type_id IS NULL))
    AND ((target = target_id) OR (target IS NULL AND target_id IS NULL))
    AND stop IS NULL;
   PERFORM pg_advisory_unlock(inCampaign);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inCampaign);
    RAISE;
  END;
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetCampaignEvent (
 inCampaign integer,
 inIndividual bigint,
 inKind varchar,
 inPath bigint,
 inRun integer
) RETURNS integer AS $$
DECLARE
 kind_id integer;
BEGIN
 IF inCampaign IS NOT NULL AND inIndividual IS NOT NULL AND inKind IS NOT NULL THEN
  kind_id := (SELECT GetWord(inKind));
  INSERT INTO CampaignEvent (campaign, individual, kind, path, run)
  VALUES (inCampaign, inIndividual, kind_id, inPath, inRun);
 END IF;
 RETURN inCampaign;
END;
$$ LANGUAGE plpgsql;
