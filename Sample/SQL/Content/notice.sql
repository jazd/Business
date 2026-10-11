-- Notice template. One content id.
-- The open edition is a heading sentence, a link, a lede sentence, and a count.
-- fr-FR and es-MX are stored on the two sentences only.
-- class heading, lede, and note have a null target, so html and mime both receive them.
-- ExampleFill returns the link URL and the count.

DO $$
DECLARE
 content_id integer;
 heading_id integer;
 lede_id integer;
 note_id integer;
 sent1 integer;
 sent2 integer;
BEGIN
 content_id := SetContent('Notice');
 PERFORM StopContent(content_id);

 heading_id := SetFormat('Notice heading');
 PERFORM SetFormatAttribute(heading_id, 'class', 'heading', NULL);
 lede_id := SetFormat('Notice lede');
 PERFORM SetFormatAttribute(lede_id, 'class', 'lede', NULL);
 note_id := SetFormat('Notice note');
 PERFORM SetFormatAttribute(note_id, 'class', 'note', NULL);

 sent1 := GetSentence('Here is the notice');
 sent2 := GetSentence('Items ready');
 INSERT INTO Sentence (id, culture, value, length)
 SELECT sent1, 1036, 'Voici l''avis', char_length('Voici l''avis')
 WHERE NOT EXISTS (
  SELECT 1 FROM Sentence WHERE id = sent1 AND culture = 1036
 );
 INSERT INTO Sentence (id, culture, value, length)
 SELECT sent2, 1036, 'Articles prêts', char_length('Articles prêts')
 WHERE NOT EXISTS (
  SELECT 1 FROM Sentence WHERE id = sent2 AND culture = 1036
 );
 INSERT INTO Sentence (id, culture, value, length)
 SELECT sent1, 2058, 'Aquí está el aviso', char_length('Aquí está el aviso')
 WHERE NOT EXISTS (
  SELECT 1 FROM Sentence WHERE id = sent1 AND culture = 2058
 );
 INSERT INTO Sentence (id, culture, value, length)
 SELECT sent2, 2058, 'Artículos listos', char_length('Artículos listos')
 WHERE NOT EXISTS (
  SELECT 1 FROM Sentence WHERE id = sent2 AND culture = 2058
 );

 PERFORM SetContentElement(content_id, 1, heading_id, NULL, sent1, NULL, NULL, NULL, NULL);
 PERFORM SetContentElement(content_id, 2, note_id, NULL, NULL, NULL, NULL, 'link', 'url');
 PERFORM SetContentElement(content_id, 3, lede_id, NULL, sent2, NULL, NULL, NULL, NULL);
 PERFORM SetContentElement(content_id, 4, NULL, NULL, NULL, NULL, NULL, 'count', 'number');
END $$;

SELECT sequence, kind, value, name, attribute, identifier, identifierType
FROM ContentBody(
 (
  SELECT Content.id
  FROM Content
  JOIN Sentence ON Sentence.id = Content.name
   AND Sentence.culture = 1033
   AND Sentence.value = 'Notice'
  LIMIT 1
 ),
 'html',
 'fr-FR'
);

SELECT sequence, kind, value, name, attribute, identifier, identifierType
FROM ContentBody(
 (
  SELECT Content.id
  FROM Content
  JOIN Sentence ON Sentence.id = Content.name
   AND Sentence.culture = 1033
   AND Sentence.value = 'Notice'
  LIMIT 1
 ),
 'html',
 'es-MX'
);
