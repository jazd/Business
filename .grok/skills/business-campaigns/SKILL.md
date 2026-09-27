---
name: business-campaigns
description: >
  Run email and postal campaigns on the Business schema: sequenced content,
  path attachments, start/stop history, read receipts, and Period send
  windows (business hours, weekends, holidays). Use for /business-campaigns,
  mailing a list, or US mail of the same content. Body copy is
  /business-cms. Sessions and list subscribe are /business-sites.
user-invocable: true
metadata:
  short-description: "Campaign lifecycle, mail, and send windows"
---

# /business-campaigns — Email and postal campaigns

Procedures write. Views read. A list is the audience (`ListIndividual`). A campaign is one sending of ordered content to that list. `ContentList` is standing content on a list name, not the campaign body.

PostgreSQL: `PostgreSQL/procedures.d/45-content.sql`. Shop: `Bash/sqlite/SetCampaign`, `StartCampaign`, `StopCampaign`, and the Set/Stop helpers next to them.

Build the body with `/business-cms` (`SetContent`, `SetContentElement`). Subscribe people with `/business-sites` (`ListSubscribeEmail`).

## Create

```sql
SELECT SetCampaign('Spring note', 'Example', 'Pro', 'email', NULL);
-- name, list name, optional list set, channel (email or mail), optional period id
SELECT SetCampaignContent(campaignId, contentId);   -- append
SELECT SetCampaignContent(campaignId, contentId, 1);
SELECT SetCampaignAttachment(campaignId, pathId, NULL, 'brochure', NULL);
-- type, target. NULL target is every output (html, txt, email, document, mail).
SELECT SetCampaignAttachment(campaignId, pathId, NULL, 'brochure', 'html');
```

`CampaignContents` and `CampaignAttachments` are the unstopped rows, `sequence` order. Filter attachments with `target IS NULL OR target = 'html'`.

`StopCampaignContent` / `StopCampaignAttachment` end that row only.

## Who receives it

`CampaignRecipients` is current members of the campaign list (and list set, when the campaign set one). `email` is the primary `IndividualEmail` (`type` NULL). `address` is the primary `IndividualAddress`.

If primary is null and the person has exactly one unstopped email (any type), use that row. Same rule for address. Do not store a copy of the mailbox or street on the campaign.

Channel `email` uses the email. Channel `mail` uses the address (US mail of the same rendered content).

## Language

Render with `/business-cms`: set `inject_culture` from `Credential.culture` for that individual, then read `ContentElements`. The content id does not change per language. Missing translation falls back to en-US (1033) inside `I18NWord` / `I18NSentence` / `I18NParagraph`.

## Start and stop

```sql
SELECT StartCampaign(campaignId);  -- new CampaignRun; no-op if one is open
SELECT StopCampaign(campaignId);   -- fills stop on the open run
```

`CampaignRuns` is every start. `stop` NULL is the open run. A later start is another row. This is not a `Period` span.

Send only when a run is open and the period allows it:

```sql
SELECT r.campaign
FROM CampaignRuns r
JOIN Campaign c ON c.id = r.campaign
WHERE r.stop IS NULL
 AND (
  c.period IS NULL
  OR c.period IN (SELECT period FROM TimePeriod WHERE open)
 );
```

`Period.exclude` is not applied by `TimePeriod`. Model the days you allow (Monday–Friday), not a weekend row with `exclude`.

Static examples in `Static/2_Event.sql`:

| Period | Meaning |
|--------|---------|
| 1 | Christmas Day (25 December) |
| 2 | Thanksgiving (fourth Thursday in November) |
| 5 | New Year's Day |
| 8 | Independence Day |
| 13 | Breakfast (`TimeOfDay` 08:00–10:00) |

`SetCampaign(..., period)` stores `PeriodName.period`. NULL means any time during an open run. A breakfast-only campaign uses period 13. A holiday hold is a period you build the same way (a `MonthDay` or `DayOfWeek` span on one period id). Several spans on one period must all be open (`TimePeriod` uses `bool_AND`).

## Tracking

```sql
SELECT SetCampaignEvent(campaignId, individualId, 'sent', NULL, runId);
SELECT SetCampaignEvent(campaignId, individualId, 'read', pathId, runId);
```

Always inserts. `kind` is a Word (`sent`, `read`, `bounce`, `delivered`, `returned`). `path` is optional (which link). `run` is optional (`CampaignRuns.run`). `CampaignEvents` is the log. Do not stop or delete events.

## Order of work

1. Content and translation (`/business-cms`).
2. `SetCampaign` with list, channel, and period.
3. `SetCampaignContent` and attachments.
4. `StartCampaign` when `TimePeriod` is open (or period is NULL).
5. For each `CampaignRecipients` row, render in that person's `Credential.culture`, send, `SetCampaignEvent` `sent`.
6. On receipt, `SetCampaignEvent` `read`.
7. `StopCampaign` when the flight ends. Start again later for another run.
