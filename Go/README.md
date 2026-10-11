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
a Sentence id because `Site.name` links to Sentence. A site that already
holds a Word id for the same text is returned unchanged. See
`docs/0.2.15-downstream.md`.

`ClientCulture` sets the connection culture. `ContentBody`, `SiteContent`,
and `ListContent` return the current edition for one target. A target
attribute wins over the null-target row with the same name.

`ComposeContent`, `ComposeSite`, and `ComposeList` walk those rows once.
An empty culture uses `ClientCulture`. A culture name is passed to the
three-argument read. A dynamic element calls the function
`Dynamic(name, kind)`; a nil function skips it. A nil renderer uses `HTML`
for `html`, `MIME` for `mime`, and newline-joined text for `txt`. `HTML`
and `MIME` are exported. `HTML` reads the class tokens `heading`, `lede`,
and `note`. `MIME` is multipart/alternative: `text/plain`, then that HTML.
A piece with `Squash` set joins with the next piece when the class token
matches, the sequences are consecutive, and place and content match. Any
squash word is a space for now. The texts join with one space. A custom
renderer receives the pieces still separate. An empty result writes nothing.
CSS stays with the caller.

`Sample/SQL/Content/notice.sql` stores a heading, a `link`, an unsquashed
lede and `count`, then that pair with `squash` `space`. `ExampleFill`
returns a fixed URL for `link`/`url` and `2` for `count`/`number`. The
marked pair renders as one line, `2` then the sentence.

From this directory, `go run ./cmd/render` prints that rendering. The default
connection is host `127.0.0.1`, port `5432`, user `test`, password `dbfit`,
database `MyCo`, the same server `make pgsqldb` and DbFit use. `PGHOST`,
`PGPORT`, `PGUSER`, `PGPASSWORD`, and `PGDATABASE` override those values.

```
go run ./cmd/render -content Notice -target html
go run ./cmd/render -content Notice -target html -culture fr-FR
go run ./cmd/render -content Notice -target html -culture es-MX
go run ./cmd/render -content 10
go run ./cmd/render -list Example -target txt
```

Leave off `-culture` for en-US. `-list Example` writes nothing when that list has no rows.

`EntitlementGrant` returns the current period for one individual, list, set,
and source. `EntitlementSet` stops that row with reason `replaced` and inserts
the next version. `EntitlementReference` stores an outside id on one version.

`Sample/PostgreSQL/Go` is the older AnonymousSession sample. New callers use
this package.

SQLite has no `SetSession`. The Bash scripts under `Bash/sqlite` are the
SQLite helpers.
