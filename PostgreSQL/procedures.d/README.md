# PostgreSQL procedures (split by domain)

Source of truth for Business PL/pgSQL is this directory, **not** a hand-edited
monolith. Files load in **lexicographic order** (prefix `00`, `10`, … `99`).

## Why order matters

Later domains call earlier ones (e.g. `GetPart` uses `GetWord` / `GetSentence`;
`AnonymousSession` uses software + path helpers; `AddCargo` uses `Book`).
PostgreSQL requires callees to exist at `CREATE FUNCTION` time for some
dependency checks, and we keep a single deterministic order for reviews and
upgrades.

## Assemble

From repo root:

```bash
./scripts/assemble-pg-procedures.sh
# writes PostgreSQL/procedures.sql (gitignored — do not commit)
```

`make pgsqldb` and related targets depend on that assemble step.  
**`PostgreSQL/procedures.sql` is a build product**, same idea as `schema.pgsql`.

## Add a new domain file

1. Pick a numeric prefix between existing steps if dependencies require it
   (e.g. `85-foo.sql` after `80-dag`, before `90-accounting`).
2. Put `CREATE OR REPLACE FUNCTION` definitions only in that file (plus any
   `DROP`/`CREATE TYPE` that belong with that domain).
3. Run `./scripts/assemble-pg-procedures.sh` and load/test.
4. Update the living upgrade script `PostgreSQL/0.2.8-0.2.9.sql` (or current
   hop) the same way other procedure changes do.

## Mapping to genDiagrams.sh groups

| File | Diagram / domain |
|------|------------------|
| 10-i18n | i18n |
| 20-geo | addresses (location/postal) |
| 30-individual | individual |
| 40-contacts | individual_email, phones, individual_path |
| 50-lists | lists |
| 60-software | software, assemblies |
| 65-est | est (PutAssemblyPublicKey, CSR, Certificate) |
| 70-session | web_session |
| 80-dag | dag |
| 90-accounting | accounting |
| 95-inventory | inventory |
| 99-schema | SchemaVersion |

Events/periods are mostly views + static data. EST write helpers live in
`65-est.sql` (PutAssemblyPublicKey, PutCertificateSigningRequest,
PutAssemblyCertificateSigningRequest, PutCertificate). Process tables remain
schema/static-first.
