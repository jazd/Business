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
`10-i18n.sql`. Shop SQLite uses the writer names under `Bash/sqlite/`.
`ClientCulture(name)`, `FormatFor`, `ContentBody`, `SiteContent`, and
`ListContent` are PostgreSQL. The Go client is `Go/content.go`.

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

Read through `I18NWord`, `I18NSentence`, `I18NParagraph`. Those views use `ClientCulture()` (default 1033 / en-US). Set the connection culture with the name. NULL clears it, so reads fall back to 1033.

```sql
SELECT ClientCulture('es-MX');
SELECT ClientCulture(NULL);
```

A person's chosen language is `Credential.culture`. A visitor's choice is `Session.culture` (NULL means en-US). `SetSessionCulture(session, 'es-MX')` sets it. `SetSessionCulture(session, NULL)` clears it. `SetSession` does not change it. `IndividualSessions.culture` is that code.

`ContentCultures` lists cultures that can show every element of the current edition. 1033 is always included. A site language menu is that view for the content on the site. Set `ClientCulture` before `ContentElements` or the two-argument `ContentBody`, `SiteContent`, and `ListContent`. Pass `Culture.name` as the third argument to read that culture and leave `ClientCulture` unchanged. A null or unknown name reads culture 1033. A missing translation keeps the element and uses the 1033 text of the same id. Do not copy translated text into a second content id. SQLite reads `ContentElements`. That text is culture 1033.

## Format

`SetFormat('Body copy')` returns a format id (sentence name).

`SetFormatAttribute(format, name, value, target)` — `target` NULL is global (every output). A target (`txt`, `document`, `html`, `mime`) is that output only. Name, value, and target are `GetIdentifier` words: one row, `culture` null. `StopFormatAttribute` ends that row only.

`class` is the attribute name. The value is the token a stylesheet or a template already knows (`lede`, `heading`). A target row wins over the null-target row with the same name. `FormatFor(format, target)` returns the winning name and value. `FormatAttributes` and `FormatFor` read name, value, and target from `Word` where `culture` is null. HTML, MIME, and the document file stay in the application.

`FormatAttributes` is the unstopped list, including both a null target and a specific target. `ContentElementAttributes` places those rows on the current edition.

## Content

`SetContent('Home page')` is the stable id. Sites and lists keep that id.

`SetContentElement(content, sequence, format, word, sentence, paragraph, argument)` writes the open edition, or opens one. Exactly one of word, sentence, or paragraph is set. The same sequence on that edition is a no-op. `argument` is optional and only stored on a word element, through `GetWord`.

A dynamic element passes no word, sentence, or paragraph, and passes a name and a type. Both are `GetIdentifier` values, stored on `ContentElement.name` and `ContentElement.type`. `GetIdentifier` runs on that write only. The nine-argument form is `SetContentElement(content, sequence, format, word, sentence, paragraph, argument, name, type)`. The older forms pass null identifiers.

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

"Thank you for your subscription" is two elements, not one sentence with a brace. See `Sample/SQL/Content/thank-you.sql` and `Static/6_Content.sql` (content id 10). Element 1 is sentence 80110. Element 2 is word 80110 (`subscription`) with argument 80111 (`subscriptions`). Cultures on those ids: en-US, fr-FR, pl-PL, es-MX.

`StopContent(content)` closes the edition. The next `SetContentElement` starts a new edition. Old elements stay on the stopped edition.

| View | Rows |
|------|------|
| `ContentElements` | Current edition, `sequence` order. `value` follows `ClientCulture()`. `identifier` and `identifierType` are the dynamic name and type. |
| `ContentElementAttributes` | That edition plus every unstopped attribute (null target and specific target) |
| `ContentHistory` | Every edition, including `stop`, with the same kind and identifier columns |
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

Kind is `word`, `sentence`, `paragraph`, or `dynamic`. A word with `argument` is kind `word`. A dynamic row has a null `value`. `name` and `attribute` are the winning token for that target. An element with no format has a null attribute.

```sql
SELECT place, content, sequence, kind, element, value, format, argument,
 name, attribute, identifier, identifierType
FROM SiteContent(siteId, 'html', cultureName);

SELECT sequence, kind, element, value, format, argument, name, attribute,
 identifier, identifierType
FROM ContentBody(contentId, 'html', 'fr-FR');

SELECT place, content, sequence, kind, element, value, format, argument,
 name, attribute, identifier, identifierType
FROM ListContent('Example', 'txt', 'fr-FR');
```

`argument` is the count name. The count is not stored. Pass it to `PluralWord(element, count)` when `kind` is `word`.

## What this skill does not do

It does not render HTML, MIME, or the document file, start a campaign, or pick a postal address. Those steps are `/business-campaigns` and the application.
