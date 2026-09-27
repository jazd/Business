---
name: business-cms
description: >
  Assemble ordered, translatable site pages and notification bodies on the
  Business schema: Word, Sentence, Paragraph, Format, Content editions,
  ContentSite, and ContentList. Use for /business-cms, page copy, email
  body content, or language selection via ClientCulture. Not for campaign
  start/stop or mailings (use /business-campaigns) and not for shop books
  (use /business-bookkeeper).
user-invocable: true
metadata:
  short-description: "CMS pages, formats, and translations"
---

# /business-cms — Pages and notification bodies

Procedures write. Views read. End a fact with `stop`. Do not DELETE history.

PostgreSQL procedures live in `PostgreSQL/procedures.d/45-content.sql` and
`10-i18n.sql`. Shop SQLite uses the same names under `Bash/sqlite/`.

Sessions and list membership: `/business-sites`. Sending a campaign:
`/business-campaigns`.

## Atoms

| Call | Stores |
|------|--------|
| `GetWord` | One idea shorter than a sentence. `varchar(25)`. |
| `GetSentence` | One sentence. |
| `GetParagraph` | One paragraph. No length column. |

Each returns a **concept id**. The same id with another `culture` row is the translation. `GetParagraph` / `GetSentence` / `GetWord` on a new culture string create a **new** id. To translate, insert another row with the **existing** id:

```sql
INSERT INTO Paragraph (id, culture, value)
SELECT 42, (SELECT code FROM Culture WHERE name = 'es-MX'), 'Texto traducido.';
```

Read through `I18NWord`, `I18NSentence`, `I18NParagraph`. Those views use `ClientCulture()` (default 1033 / en-US). For a database session, after `SELECT ClientCulture();` has created `inject_culture`:

```sql
DELETE FROM inject_culture;
INSERT INTO inject_culture (value)
SELECT code FROM Culture WHERE name = 'es-MX';
```

A person's chosen language is `Credential.culture`. Set `inject_culture` from that code before reading `ContentElements`, then send or render. Do not copy translated text into a second content id.

## Format

`SetFormat('Body copy')` returns a format id (sentence name).

`SetFormatAttribute(format, name, value, target)` — `target` NULL is global (every output). A target Word (`txt`, `markdown`, `document`, `html`) is the rare override. `StopFormatAttribute` ends that row only.

`FormatAttributes` is the unstopped list. When rendering one target, use the row for that target if present, otherwise the row with `target` NULL and the same name.

## Content

`SetContent('Home page')` is the stable id. Sites and lists keep that id.

`SetContentElement(content, sequence, format, word, sentence, paragraph, argument)` writes the open edition, or opens one. Exactly one of word, sentence, paragraph is set. The same sequence on that edition is a no-op. `argument` is optional and only stored on a word element.

## Plurals

`WordPlural` holds the other forms of a singular Word. `plural` is 0 zero, 2 two, 3 few, 4 many. The singular form is the Word itself. Static `1_Plural.sql` shows Cat / Cats, Chat / Chats, Kot / Koty / Kotów, Gato / Gatos on one concept id (80000).

The count is not stored on the element. Name the count with `argument` (`items`, `guests`). At render time the caller supplies that count and calls `PluralWord(wordId, count)`. The form follows `ClientCulture()` when that culture has the word, otherwise en-US.

| Count | Column |
|-------|--------|
| 0 | zero |
| 1 | singular |
| 2 | two |
| 3 or 4 | few |
| anything else | many |

`ContentElements.argument` is that name. `ContentElementPlurals` lists singular, zero, two, few, and many for the current edition so a renderer can pick without calling `PluralWord`. Sentences and paragraphs are not pluralized.

`StopContent(content)` closes the edition. The next `SetContentElement` starts a new edition. Old elements stay on the stopped edition.

| View | Rows |
|------|------|
| `ContentElements` | Current edition, `sequence` order, `value` in the client culture |
| `ContentHistory` | Every edition, including `stop` |
| `ContentSites` | Unstopped site placements, `sequence` order |
| `ContentLists` | Unstopped list placements (notification bodies tied to a list name) |

```sql
SELECT SetContentSite(siteId, contentId);          -- next sequence
SELECT SetContentSite(siteId, contentId, 1);
SELECT StopContentSite(siteId, contentId);

SELECT SetContentList('Example', contentId);
SELECT StopContentList('Example', contentId);
```

A second `SetContentSite` for the same pair does not move `sequence`. Stop it and set it again to place it in a new slot.

Page for a site, in the session language:

```sql
SELECT e.sequence, e.kind, e.value, e.format
FROM ContentSites s
JOIN ContentElements e ON e.content = s.content
WHERE s.site = $1
ORDER BY s.sequence, e.sequence;
```

Notification body for a list is the same join on `ContentLists`.

## What this skill does not do

It does not render HTML or MIME, start a campaign, or pick a postal address. Those steps are `/business-campaigns` and the application.
