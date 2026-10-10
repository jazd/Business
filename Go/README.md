# Go client for the Business schema

PostgreSQL helpers with the same names as `Bash/sqlite` (`GetWord`, `GetEmail`,
`GetIndividualEmail`, `SetSession`, and the rest). Each method is
`SELECT SomeProcedure(...)`. The procedures find-or-insert, stop, or fill a
NULL. This package does not write tables.

```go
db, err := business.OpenFromEnv() // PGHOST, PGUSER, PGPASSWORD, PGDATABASE
id, err := db.GetWord(ctx, "Example")
```

`GetEmail` on a stranger stores the mailbox. `GetIndividualEmail` creates a
person when that mailbox is not already on IndividualEmail. `GetSite` stores
a Sentence id because `Site.name` links to Sentence. See
`docs/0.2.14-downstream.md`.

`ClientCulture` sets the connection culture. `ContentBody`, `SiteContent`,
and `ListContent` return the current edition for one target (`html`, `txt`,
or `document`). A target attribute wins over the null-target row with the
same name.

`EntitlementGrant` returns the current period for one individual, list, set,
and source. `EntitlementSet` stops that row with reason `replaced` and inserts
the next version. `EntitlementReference` stores an outside id on one version.

`Sample/PostgreSQL/Go` is the older AnonymousSession sample. New callers use
this package.

SQLite has no `SetSession`. The Bash scripts under `Bash/sqlite` are the
SQLite helpers.
