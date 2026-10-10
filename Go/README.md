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

`Sample/PostgreSQL/Go` is the older AnonymousSession sample. New callers use
this package.

SQLite has no `SetSession`. The Bash scripts under `Bash/sqlite` are the
SQLite helpers.
