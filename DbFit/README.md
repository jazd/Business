dbfit http://dbfit.github.io/dbfit/

# FitNesse

Link the schema pages into the FitNesse root. The install directory is the
directory that contains `startFitnesse.sh` and `FitNesseRoot`, not a nested
`dbfit/` folder.

```
ln -s <git root>/Business/DbFit/BusinessSchema \
  <dbfit install directory>/FitNesseRoot/BusinessSchema
```

```
cd <dbfit install directory>
./startFitnesse.sh
```

FitNesse listens on port 8085.

http://localhost:8085/BusinessSchema

# PostgreSQL

Test server:

| | |
|---|---|
| Host | `postgres` |
| Database | `MyCo` |
| User | `test` |
| Password | `dbfit` |
| Schema | `Business` |

In the Makefile set:

```
PostgreSQLServer = postgres
```

`make pgsqldb` drops and reloads the Business schema on that server.

```
cd <git root>/Business
make pgsqldb
```

Direct login:

```
psql -h postgres -U test MyCo
```

Suite setup is `DbFit/BusinessSchema/PostgreSqlSuite/SetUp/content.txt`:

```
!|dbfit.PostgresTest|
!|Connect|postgres|test|dbfit|MyCo|
```

http://localhost:8085/BusinessSchema.PostgreSqlSuite?suite

A page that does not inherit that setup needs the same `Connect` row, plus
`!path lib/*.jar`.

## PostgreSQL container

This is a separate server from the `postgres` host. Pass `PostgreSQLServer=localhost`
so `make pgsqldb` does not load the VM.

```
podman pull docker.io/library/postgres:latest
podman run -d --name my-postgres \
  -e POSTGRES_USER=admin \
  -e POSTGRES_DB=MyCo \
  -e POSTGRES_PASSWORD=dbfit \
  -p 5432:5432 \
  docker.io/library/postgres:latest
```

```
PGPASSWORD=dbfit psql -h localhost -U admin MyCo
```

```
CREATE USER test WITH PASSWORD 'dbfit';
ALTER ROLE test WITH LOGIN;
CREATE SCHEMA Business;
GRANT ALL ON SCHEMA Business TO test;
ALTER USER test SET search_path TO Business;
```

```
cd <git root>/Business
PGPASSWORD=dbfit make pgsqldb PostgreSQLServer=localhost
```

# MySQL

Test server:

| | |
|---|---|
| Host | `mysql8` |
| Server | MySQL 8 |
| Database | `MyCo` |
| Character set | `utf8mb4` / `utf8mb4_unicode_ci` |
| User | `test`@`%` |
| Password | `dbfit` |

Create the database and account as an administrator:

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
mysql -h mysql8 -u test -pdbfit MyCo
```

In the Makefile set:

```
MySQLServer = mysql8
MySQLPassword = -pdbfit
```

`make mysqldb` drops and reloads the Business tables in MySQL `MyCo`. It does
not touch the PostgreSQL server.

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
!|Connect|mysql8|test|dbfit|MyCo|
```

http://localhost:8085/BusinessSchema.MySqlSuite?suite

`MySqlSuite` links each `TableTests` page that passes on this load. It does not link `ProcedureTests`, `ViewTests`, or `XcepteionRequired`. These table pages stay unlinked: `Address` and `Postal` (the load does not create `GetAddress` or `GetPostal`), `Dual`, `Path`, `Release`, and `SchemaVersion` (MySQL reserved names), and `Entity`, `Family`, `Given`, `Sentence`, and `Word` (case-sensitive text, or an explicit id of 0).

The connection page reads `VERSION()` and does not need the tables:

http://localhost:8085/BusinessSchema.MySqlSuite.Connection

# SQL Server

Enable the tcp/ip protocol using Sql Server Configuration Manager.
Restart sqlserver.

Create the database and allow username and password logins.

```
sqlcmd -S localhost -E
```

```
CREATE DATABASE MyCo;
GO
exec sp_configure 'contained database authentication', 1
GO
Reconfigure
GO
USE [master]
GO
ALTER DATABASE [MyCo] SET CONTAINMENT = PARTIAL
GO
USE [MyCo];
GO
CREATE SCHEMA Business
GO
CREATE USER test WITH PASSWORD = '<password>', DEFAULT_SCHEMA = Business;
GO
GRANT CONTROL ON schema :: dbo TO test;
GO
GRANT CONTROL ON schema :: Business TO test;
QUIT
```

Verify login:

```
sqlcmd -S localhost -U test -P <password> -d MyCo
```

Create the Business schema:

```
sqlcmd -S localhost -E -d MyCo -i schema.sqlserver
sqlcmd -S localhost -E -d MyCo -i SQLServer\Statics.sql
```

Windows link:

```
mklink /D <dbfit install directory>\FitNesseRoot\BusinessSchema <git root>\Business\DbFit\BusinessSchema
```

```
cd <dbfit install directory>
./startFitnesse.bat
```

http://localhost:8085/BusinessSchema
