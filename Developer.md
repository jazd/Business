# Developing on the database containers

A new clone uses the podman services in `compose.dbfit.yml`. Published ports
bind `127.0.0.1`. Database files stay on named volumes.

The SQLite shop file is a separate path. See [GETTING-STARTED.md](./GETTING-STARTED.md).
Suite page notes are in [DbFit/README.md](./DbFit/README.md).

## Requirements

- podman, and `podman compose`
- `psql` and the `mysql` client (`make pgsqldb` and `make mysqldb` use them)

## First load

`make pgsqldb`, `make mysqldb`, and `make sqlserverdb` drop and reload
database `MyCo` on the server they are pointed at. `make oracledb` drops and
reloads the tables for user `test` in service `FREEPDB1`. `make db2db` drops
and reloads the tables for user `test` in database `MYCO`. The committed host
is `127.0.0.1`. That host, and `localhost`, start the matching container,
wait until it is healthy, and then load.

```
make pgsqldb
make mysqldb
make sqlserverdb
make oracledb
make db2db
```

## FitNesse

```
make dbfit
```

`make dbfit` builds `localhost/jazd/dbfit:dev` and starts `business-dbfit`
on `127.0.0.1:8085`. The image contains the FitNesse install: DbFit 3.2.0,
Connector/J 5.1.49, PostgreSQL JDBC 42.2.5, Microsoft JDBC
`mssql-jdbc-12.10.2.jre11.jar`, Oracle JDBC `ojdbc8-21.9.0.0.jar`, Db2 JDBC
`jcc-12.1.5.0.jar`, `lib/postgres.jar` linked to the PostgreSQL jar, and
`FitNesseRoot/lib` linked to `/dbfit/lib`. That start also brings up
`business-pgsql`, `business-mysql`, and `business-mssql` when they are down.
It does not start `business-oracle` or `business-db2`, and it does not reload
`MyCo`. Load the schema with the targets above. `make mssql` still writes
`schema.sqlserver`. `make oracle` still writes `schema.oracle`. `make db2`
still writes `schema.db2`. None of those three starts a container.

Suites:

```
http://127.0.0.1:8085/BusinessSchema.PostgreSqlSuite?suite
http://127.0.0.1:8085/BusinessSchema.MySqlSuite?suite
http://127.0.0.1:8085/BusinessSchema.SqlServerSuite?suite
http://127.0.0.1:8085/BusinessSchema.OracleSuite?suite
http://127.0.0.1:8085/BusinessSchema.Db2Suite?suite
```

The FitNesse container connects as user `test`, password `dbfit`, database
`MyCo`. PostgreSQL uses compose service `business-pgsql`. MySQL uses
`business-mysql`. SQL Server uses `business-mssql` and sets
`trustServerCertificate` because the container certificate is not in the
Java trust store.

## Start again

After the image exists and the databases are loaded, this starts every
service in `compose.dbfit.yml` and keeps the volumes:

```
podman compose -f compose.dbfit.yml up -d
```

## Stop

```
make dbfit-stop
```

That stops `business-pgsql`, `business-mysql`, `business-mssql`,
`business-oracle`, `business-db2`, and `business-dbfit`. Named volumes stay.
Other containers on the machine stay as they are.

## Connect

Host tools use `127.0.0.1`. The FitNesse container uses the compose service
names, because those names resolve on the compose network.

### PostgreSQL

`business-pgsql` is `postgres:17` on `127.0.0.1:5432`. Database `MyCo`, user
`test`, password `dbfit`, schema `business`.

```
PGPASSWORD=dbfit psql -h 127.0.0.1 -U test MyCo
```

`Go/cmd/render` uses that same login and prints one rendered content, site,
or list. From `Go/`:

```
go run ./cmd/render -content Notice -target html
go run ./cmd/render -content Notice -target html -culture fr-FR
go run ./cmd/render -content Notice -target html -culture es-MX
```

Leave off `-culture` for en-US. An empty result writes nothing. The command
list is in `Go/README.md`.

### MySQL

`business-mysql` is `mysql:8.0` on `127.0.0.1:3306`. Database `MyCo`, user
`test`, password `dbfit`.

```
mysql -h 127.0.0.1 -u test -pdbfit MyCo
```

### SQL Server

`business-mssql` is SQL Server 2022 on `127.0.0.1:1433`. Database `MyCo`,
login `test`, password `dbfit`, schema `Business`. The `sa` password is
`Dbfit_sa1`.

`make mssql-start` starts the container and does not reload `MyCo`.
`make sqlcmd` opens `sqlcmd` in that container as `test`.

```
make mssql-start
make sqlcmd
```

The same client from the shell:

```
podman exec -it business-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U test -P dbfit -d MyCo
```

A shell in the container with `sqlcmd` on `PATH`:

```
podman exec -it business-mssql bash -lc 'PATH="/opt/mssql-tools18/bin:$PATH" exec bash'
```

`-C` trusts the container certificate. A `sqlcmd` on the host uses the same
login with `-S 127.0.0.1`.

### Oracle

`business-oracle` is `gvenzl/oracle-free:23.26.3-slim` on `127.0.0.1:1521`.
Service `FREEPDB1`, user `test`, password `dbfit`. `SYS` and `SYSTEM` use
`Dbfit_oracle1`. The first start initializes the database and takes several
minutes. `make dbfit` does not start this service.

`make oracle-start` starts the container and does not reload the schema.
`make oracledb` loads tables. `make oracle` still writes `schema.oracle`.
`make sqlplus` opens `sqlplus` in that container as `test`.

```
make oracle-start
make sqlplus
```

The same client from the shell:

```
podman exec -it business-oracle sqlplus test/dbfit@//localhost/FREEPDB1
```

### Db2

`business-db2` is `icr.io/db2_community/db2:12.1.5.0` on `127.0.0.1:50000`.
Database `MYCO`, user `test`, password `dbfit`. The instance owner is
`db2inst1` and that password is `Dbfit_db21`. The service adds `IPC_LOCK`,
`IPC_OWNER`, `SYS_NICE`, and `SYS_RESOURCE`, and a 2GB `/dev/shm`. It is
not privileged. The first start initializes the instance and takes several
minutes. `make dbfit` does not start this service.

`make db2-start` starts the container and does not reload the schema.
`make db2db` loads tables. `make db2` still writes `schema.db2`.
`make db2clp` opens a shell as `db2inst1`, with `db2` on `PATH`.

```
make db2-start
make db2clp
```

The same shell from the command line:

```
podman exec -it business-db2 bash -lc 'exec su - db2inst1'
```

## Another database host

```
make pgsqldb PostgreSQLServer=<host>
make mysqldb MySQLServer=<host>
make sqlserverdb SQLServerServer=<host>
make oracledb OracleServer=<host>
make db2db DB2Server=<host>
```

Any host other than `127.0.0.1` and `localhost` is used as given, and the
Makefile leaves the compose services alone. The target still drops and
reloads `MyCo` on that host.

## Another FitNesse

`make dbfit-stop` releases port 8085. The container has its own install
under `/dbfit`. A FitNesse process on the host can listen on 8085 after
that stop.

The committed suite `Connect` rows use `business-pgsql`, `business-mysql`,
and `business-mssql`.
A FitNesse process outside the compose network needs a host it can resolve.
`127.0.0.1` reaches the published container ports. Leave machine-specific
hostnames out of the committed `SetUp` files.
