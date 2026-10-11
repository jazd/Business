#!/usr/bin/env bash
# Content reads: kind dynamic, culture-null identifiers, and a culture argument.
# Applies the living PostgreSQL hop inside a transaction and rolls it back.
# MyCo must not already have ContentElement.name.
#
#   ./scripts/test-content-reads.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOP="$ROOT/PostgreSQL/0.2.14-0.2.15.sql"
PSQL=(psql -h 127.0.0.1 -U test -d MyCo -v ON_ERROR_STOP=1)
export PGPASSWORD="${PGPASSWORD:-dbfit}"

fail() {
  echo "Error: $*" >&2
  exit 1
}

cols=$("${PSQL[@]}" -Atc "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'business' AND table_name = 'contentelement' AND column_name IN ('name', 'type');")
[[ "$cols" == "0" ]] || fail "MyCo already has ContentElement name/type ($cols)"

SQL="$(mktemp)"
trap 'rm -f "$SQL"' EXIT

python3 - "$HOP" "$SQL" << 'PY'
import pathlib, sys
hop, dest = sys.argv[1:]
text = pathlib.Path(hop).read_text()
start = text.index("DO $$\n")
end = text.index("END $$;\n", start) + len("END $$;\n")
body = text[:start] + text[end:]
kept = []
for line in body.splitlines(True):
    if line.strip() in {"BEGIN;", "COMMIT;", "\\set ON_ERROR_STOP on"}:
        continue
    kept.append(line)
body = "".join(kept).strip() + "\n"
test = r'''
DO $test$
DECLARE
 content_id integer;
 sent_id integer;
 sent2_id integer;
 para_id integer;
 word_id integer;
 arg_id integer;
 format_id integer;
 site_id integer;
 got text;
 en_body text;
 n integer;
 culture_before smallint;
 words_before bigint;
 sentences_before bigint;
 paragraphs_before bigint;
 elements_before bigint;
 attributes_before bigint;
 editions_before bigint;
 fr_expected text;
 en_expected text;
BEGIN
 content_id := SetContent('Phase three read');
 sent_id := GetSentence('Phase three hello');
 sent2_id := GetSentence('Phase three only english');
 para_id := GetParagraph('Phase three paragraph');
 word_id := GetWord('phase3item');
 arg_id := GetWord('phase3items');
 INSERT INTO Sentence (id, culture, value, length)
 SELECT sent_id, 1036, 'Bonjour phase trois', 20
 WHERE NOT EXISTS (
  SELECT 1 FROM Sentence WHERE id = sent_id AND culture = 1036
 );
 INSERT INTO Word (id, culture, value)
 SELECT arg_id, 1036, 'phase3articles'
 WHERE NOT EXISTS (
  SELECT 1 FROM Word WHERE id = arg_id AND culture = 1036
 );
 PERFORM SetContentElement(content_id, 1, NULL, NULL, sent_id, NULL, NULL, NULL, NULL);
 PERFORM SetContentElement(content_id, 2, NULL, NULL, NULL, NULL, NULL, 'link', 'url');
 PERFORM SetContentElement(content_id, 3, NULL, NULL, sent2_id, NULL, NULL, NULL, NULL);
 PERFORM SetContentElement(content_id, 4, NULL, word_id, NULL, NULL, 'phase3items', NULL, NULL);
 PERFORM SetContentElement(content_id, 5, NULL, NULL, NULL, para_id, NULL, NULL, NULL);
 format_id := SetFormat('Phase three body');
 PERFORM SetFormatAttribute(format_id, 'class', 'lede', 'html');
 site_id := GetSite('phase3-read.test');
 PERFORM SetContentSite(site_id, content_id);
 PERFORM SetContentList('PhaseThreeList', content_id);

 PERFORM ClientCulture();
 culture_before := ClientCulture();
 SELECT count(*) INTO words_before FROM Word;
 SELECT count(*) INTO sentences_before FROM Sentence;
 SELECT count(*) INTO paragraphs_before FROM Paragraph;
 SELECT count(*) INTO elements_before FROM ContentElement;
 SELECT count(*) INTO attributes_before FROM FormatAttribute;
 SELECT count(*) INTO editions_before FROM ContentEdition;

 fr_expected := E'1|sentence|Bonjour phase trois|||\n'
  || E'2|dynamic||link|url|\n'
  || E'3|sentence|Phase three only english|||\n'
  || E'4|word|phase3item|||phase3articles\n'
  || E'5|paragraph|Phase three paragraph|||';
 en_expected := E'1|sentence|Phase three hello|||\n'
  || E'2|dynamic||link|url|\n'
  || E'3|sentence|Phase three only english|||\n'
  || E'4|word|phase3item|||phase3items\n'
  || E'5|paragraph|Phase three paragraph|||';

 SELECT string_agg(
  sequence::text || '|' || COALESCE(kind, '') || '|' || COALESCE(value, '')
  || '|' || COALESCE(identifier, '') || '|' || COALESCE(identifierType, '')
  || '|' || COALESCE(argument, ''),
  E'\n' ORDER BY sequence
 ) INTO got
 FROM ContentBody(content_id, 'html', 'fr-FR');
 IF got IS DISTINCT FROM fr_expected THEN
  RAISE EXCEPTION 'fr body [%]', got;
 END IF;

 SELECT string_agg(
  sequence::text || '|' || COALESCE(kind, '') || '|' || COALESCE(value, '')
  || '|' || COALESCE(identifier, '') || '|' || COALESCE(identifierType, '')
  || '|' || COALESCE(argument, ''),
  E'\n' ORDER BY sequence
 ) INTO got
 FROM ContentBody(content_id, 'html', 'zz-ZZ');
 IF got IS DISTINCT FROM en_expected THEN
  RAISE EXCEPTION 'unknown culture [%]', got;
 END IF;

 SELECT string_agg(
  sequence::text || '|' || COALESCE(kind, '') || '|' || COALESCE(value, '')
  || '|' || COALESCE(identifier, '') || '|' || COALESCE(identifierType, '')
  || '|' || COALESCE(argument, ''),
  E'\n' ORDER BY sequence
 ) INTO en_body
 FROM ContentBody(content_id, 'html');
 IF en_body IS DISTINCT FROM en_expected THEN
  RAISE EXCEPTION 'client culture body [%]', en_body;
 END IF;
 IF ClientCulture() IS DISTINCT FROM culture_before THEN
  RAISE EXCEPTION 'ClientCulture changed from % to %', culture_before, ClientCulture();
 END IF;

 SELECT count(*) INTO n FROM SiteContent(site_id, 'html', 'fr-FR');
 IF n <> 5 THEN
  RAISE EXCEPTION 'site rows %', n;
 END IF;
 SELECT count(*) INTO n
 FROM SiteContent(site_id, 'html', 'fr-FR')
 WHERE place = 1 AND sequence = 2 AND kind = 'dynamic'
  AND value IS NULL AND identifier = 'link' AND identifierType = 'url';
 IF n <> 1 THEN
  RAISE EXCEPTION 'site dynamic rows %', n;
 END IF;

 SELECT string_agg(
  sequence::text || '|' || COALESCE(kind, '') || '|' || COALESCE(value, '')
  || '|' || COALESCE(identifier, '') || '|' || COALESCE(identifierType, '')
  || '|' || COALESCE(argument, ''),
  E'\n' ORDER BY sequence
 ) INTO got
 FROM ListContent('PhaseThreeList', 'txt', 'fr-FR');
 IF got IS DISTINCT FROM fr_expected THEN
  RAISE EXCEPTION 'list body [%]', got;
 END IF;
 SELECT count(*) INTO n FROM ListContent('no-such-phase3-list', 'txt', 'fr-FR');
 IF n <> 0 THEN
  RAISE EXCEPTION 'missing list rows %', n;
 END IF;

 SELECT name || '|' || value INTO got FROM FormatFor(format_id, 'html');
 IF got IS DISTINCT FROM 'class|lede' THEN
  RAISE EXCEPTION 'FormatFor [%]', got;
 END IF;
 SELECT name || '|' || value || '|' || COALESCE(target, '') INTO got
 FROM FormatAttributes WHERE format = format_id;
 IF got IS DISTINCT FROM 'class|lede|html' THEN
  RAISE EXCEPTION 'FormatAttributes [%]', got;
 END IF;

 SELECT kind || '|' || COALESCE(identifier, '') || '|' || COALESCE(identifierType, '')
 INTO got
 FROM ContentElements
 WHERE content = content_id AND sequence = 2;
 IF got IS DISTINCT FROM 'dynamic|link|url' THEN
  RAISE EXCEPTION 'element view [%]', got;
 END IF;
 SELECT kind INTO got FROM ContentHistory
 WHERE content = content_id AND sequence = 2;
 IF got IS DISTINCT FROM 'dynamic' THEN
  RAISE EXCEPTION 'history [%]', got;
 END IF;

 SELECT string_agg(kind, ',' ORDER BY sequence) INTO got
 FROM ContentElements WHERE content = 10;
 IF got IS DISTINCT FROM 'sentence,word' THEN
  RAISE EXCEPTION 'content 10 [%]', got;
 END IF;

 IF (SELECT count(*) FROM Word) IS DISTINCT FROM words_before
  OR (SELECT count(*) FROM Sentence) IS DISTINCT FROM sentences_before
  OR (SELECT count(*) FROM Paragraph) IS DISTINCT FROM paragraphs_before
  OR (SELECT count(*) FROM ContentElement) IS DISTINCT FROM elements_before
  OR (SELECT count(*) FROM FormatAttribute) IS DISTINCT FROM attributes_before
  OR (SELECT count(*) FROM ContentEdition) IS DISTINCT FROM editions_before THEN
  RAISE EXCEPTION 'a read wrote a row';
 END IF;
END
$test$;
'''
pathlib.Path(dest).write_text("BEGIN;\n" + body + test + "ROLLBACK;\n")
PY

set +e
"${PSQL[@]}" -f "$SQL"
status=$?
set -e

leftover=$("${PSQL[@]}" -Atc "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'business' AND table_name = 'contentelement' AND column_name IN ('name', 'type');")
[[ "$leftover" == "0" ]] || fail "ContentElement name/type still present after rollback"
funcs=$("${PSQL[@]}" -Atc "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'business' AND p.proname = 'contentbody' AND pg_get_function_identity_arguments(p.oid) LIKE '%inculture%';")
[[ "$funcs" == "0" ]] || fail "ContentBody culture argument still present after rollback"
[[ "$status" -eq 0 ]] || exit "$status"
echo "Content reads ok"
