dbfit http://dbfit.github.io/dbfit/

# FitNesse

`business-dbfit` serves the suites on `127.0.0.1:8085`. The image downloads
DbFit 3.2.0, then adds `mysql-connector-java-5.1.49.jar` and
`postgresql-42.2.5.jar`. `lib/postgres.jar` points at that PostgreSQL jar.
`FitNesseRoot/lib` points at `/dbfit/lib`. Connector/J 5.1.36 is not in `lib/`.

```
podman build -f Containerfile.dbfit -t localhost/jazd/dbfit:dev .
podman compose -f compose.dbfit.yml up -d business-dbfit
```

`make dbfit` builds that image and starts the service. That start also
brings up `business-pgsql`, `business-mysql`, and `business-mssql` when they
are down, and does not reload `MyCo`. `make dbfit-stop` stops every service
in `compose.dbfit.yml` and leaves the named database volumes in place.

Compose mounts `DbFit/BusinessSchema` at the image's `FitNesseRoot/BusinessSchema`.
The PostgreSQL suite connects to `business-pgsql`. The MySQL suite connects to
`business-mysql`. Both use `test` / `dbfit` / `MyCo`.

http://127.0.0.1:8085/BusinessSchema

# PostgreSQL

`make pgsqldb` drops and reloads the Business schema in database `MyCo`.
The default host is `127.0.0.1`. That host, and `localhost`, start compose
service `business-pgsql` from `compose.dbfit.yml`, wait until it is healthy,
and then load. A different `PostgreSQLServer` is used as given, and the
Makefile leaves the containers alone.

| | |
|---|---|
| Host | `127.0.0.1` |
| Image | `docker.io/library/postgres:17` |
| Database | `MyCo` |
| User | `test` |
| Password | `dbfit` |
| Schema | `business` |

The image creates the user and the database. `PostgreSQL/container-init.sql`
creates schema `business` and sets `search_path` to `business, public`.
`PostgreSQL/pre.sql` begins with `SET search_path TO Business`. The Makefile
applies `container-init.sql` before each load of a container host.

In the Makefile:

```
PostgreSQLServer = 127.0.0.1
```

```
cd <git root>/Business
make pgsqldb
```

Direct login:

```
PGPASSWORD=dbfit psql -h 127.0.0.1 -U test MyCo
```

Suite setup is `DbFit/BusinessSchema/PostgreSqlSuite/SetUp/content.txt`:

```
!|dbfit.PostgresTest|
!|Connect|business-pgsql|test|dbfit|MyCo|
```

http://127.0.0.1:8085/BusinessSchema.PostgreSqlSuite?suite

A page that does not inherit that setup needs the same `Connect` row, plus
`!path lib/*.jar`.

# MySQL

`make mysqldb` drops and reloads the Business tables in MySQL `MyCo`. The
default host is `127.0.0.1`. That host, and `localhost`, start compose
service `business-mysql` from `compose.dbfit.yml`, wait until it is healthy,
and then load. A different `MySQLServer` is used as given, and the Makefile
leaves the containers alone. This load does not touch the PostgreSQL server.

| | |
|---|---|
| Host | `127.0.0.1` |
| Image | `docker.io/library/mysql:8.0` |
| Database | `MyCo` |
| Character set | `utf8mb4` / `utf8mb4_unicode_ci` |
| User | `test` |
| Password | `dbfit` |
| Authentication | `mysql_native_password` |

The service starts with `log_bin_trust_function_creators=1`. `ClientCulture`
and `GetSentence` need that while binary logging is on.

On a MySQL server that this Makefile does not start, create the database and
account as an administrator:

```
CREATE DATABASE MyCo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'test'@'%' IDENTIFIED WITH mysql_native_password BY 'dbfit';
GRANT ALL PRIVILEGES ON MyCo.* TO 'test'@'%';
SET PERSIST log_bin_trust_function_creators = 1;
```

`GRANT ALL PRIVILEGES ON MyCo.*` does not let `test` create stored functions
while binary logging is on. `ClientCulture` and `GetSentence` need
`log_bin_trust_function_creators`. `test` cannot set that variable. An
administrator sets it with `SET PERSIST`, which keeps it across a restart.

If the account already exists with `caching_sha2_password`, change it:

```
ALTER USER 'test'@'%' IDENTIFIED WITH mysql_native_password BY 'dbfit';
FLUSH PRIVILEGES;
```

DbFit loads `com.mysql.jdbc.Driver`. Connector/J 5.1.36 fails the MySQL 8
handshake. Use `mysql-connector-java-5.1.49.jar` in the FitNesse `lib`
directory, and do not leave 5.1.36 on that classpath. 5.1.49 still cannot
log in with `caching_sha2_password`, which is why the account uses
`mysql_native_password`.

Check the login:

```
mysql -h 127.0.0.1 -u test -pdbfit MyCo
```

In the Makefile:

```
MySQLServer = 127.0.0.1
MySQLPassword = -pdbfit
```

```
cd <git root>/Business
make mysqldb
```

`MySQL/pre.sql` creates `Dual` as a quoted name because `Dual` is reserved.
Unquoted `Dual` is MySQL's dummy table, and `SELECT * FROM Dual` returns
"No tables used".

Suite setup is `DbFit/BusinessSchema/MySqlSuite/SetUp/content.txt`:

```
!|dbfit.MySqlTest|
!|Connect|business-mysql|test|dbfit|MyCo|
```

http://127.0.0.1:8085/BusinessSchema.MySqlSuite?suite

`MySqlSuite` links each `TableTests` page that passes on this load. It does not link `ProcedureTests`, `ViewTests`, or `XcepteionRequired`. These table pages stay unlinked: `Address` and `Postal` (the load does not create `GetAddress` or `GetPostal`), `Dual`, `Path`, `Release`, and `SchemaVersion` (MySQL reserved names), and `Entity`, `Family`, `Given`, `Sentence`, and `Word` (case-sensitive text, or an explicit id of 0).

The connection page reads `VERSION()` and does not need the tables:

http://127.0.0.1:8085/BusinessSchema.MySqlSuite.Connection

# SQL Server

`make sqlserverdb` drops and reloads the Business schema in database `MyCo`.
The default host is `127.0.0.1`. That host, and `localhost`, start compose
service `business-mssql` from `compose.dbfit.yml`, wait until it is healthy,
and then load. A different `SQLServerServer` is used as given, and the
Makefile leaves the containers alone. For that host the target prints the
`sqlcmd -E` commands and does not run them.

| | |
|---|---|
| Host | `127.0.0.1` |
| Image | `mcr.microsoft.com/mssql/server:2022-latest` |
| Database | `MyCo` |
| User | `test` |
| Password | `dbfit` |
| sa password | `Dbfit_sa1` |
| Schema | `Business` |

`SQLServer/container-init.sql` creates database `MyCo`, login `test` with
`CHECK_POLICY` off, and schema `Business` as that login's default schema.
The load runs `sqlcmd` from the image with `-C`.

In the Makefile:

```
SQLServerServer = 127.0.0.1
```

```
cd <git root>/Business
make sqlserverdb
```

`make mssql-start` starts the container and does not reload `MyCo`.
`make mssql` still writes `schema.sqlserver`. `make sqlcmd` opens `sqlcmd`
in that container as `test`.

```
podman exec -it business-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U test -P dbfit -d MyCo
```

A shell in the container with `sqlcmd` on `PATH`:

```
podman exec -it business-mssql bash -lc 'PATH="/opt/mssql-tools18/bin:$PATH" exec bash'
```

`-C` trusts the container certificate.

Suite setup is `DbFit/BusinessSchema/SqlServerSuite/SetUp/content.txt`:

```
!|dbfit.SqlServerTest|
!|Connect|business-mssql;trustServerCertificate=true|test|dbfit|MyCo|
```

http://127.0.0.1:8085/BusinessSchema.SqlServerSuite?suite

The image includes `mssql-jdbc-12.10.2.jre11.jar`. `trustServerCertificate`
is set because the container certificate is not in the Java trust store.

`SqlServerSuite/TableTests` runs the shared table pages whose SQL already
works, and local copies of the pages that used `LIMIT 1`. Those copies use
`SELECT TOP 1`. `SchemaVersion` quotes `[schema]`. `PeriodName` and
`ListIndividualName` keep the insert and omit the check that expects a
static row. These pages stay out: `Address`, `DayOfWeek`, `Month`,
`MonthDay`, `Period`, `Postal`, `TimeOfDay`, and `Timezone` (this load has
no rows), and `Entity`, `Family`, `Given`, `Sentence`, and `Word`
(case-sensitive text, or an explicit id on an identity column).

`SQLServer/post.sql` reseeds those identity columns to the same floors as
the PostgreSQL sequences.
