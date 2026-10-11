# Developing on the database containers

A new clone uses the podman services in `compose.dbfit.yml`. Published ports
bind `127.0.0.1`. Database files stay on named volumes.

The SQLite shop file is a separate path. See [GETTING-STARTED.md](./GETTING-STARTED.md).
Suite page notes are in [DbFit/README.md](./DbFit/README.md).

## Requirements

- podman, and `podman compose`
- `psql` and the `mysql` client (`make pgsqldb` and `make mysqldb` use them)
- A FitNesse install for `make dbfit`. `DBFIT_HOME` defaults to `~/dbfit`.
  That directory supplies `startFitnesse.sh`, `plugins.properties`, and
  `lib/*.jar`, including `mysql-connector-java-5.1.49.jar`. Connector/J
  5.1.36 stays out of `lib/`.

## First load

`make pgsqldb`, `make mysqldb`, and `make sqlserverdb` drop and reload
database `MyCo` on the server they are pointed at. The committed host is
`127.0.0.1`. That host, and `localhost`, start the matching container, wait
until it is healthy, and then load.

```
make pgsqldb
make mysqldb
make sqlserverdb
```

## FitNesse

```
make dbfit
```

`make dbfit` builds `localhost/jazd/dbfit:dev` from `DBFIT_HOME` and starts
`business-dbfit` on `127.0.0.1:8085`. That also starts `business-pgsql` and
`business-mysql` when they are down. Load the schema with the targets above.
Start SQL Server with `make sqlserverdb` or with the compose command below.

Suites:

- http://127.0.0.1:8085/BusinessSchema.PostgreSqlSuite?suite
- http://127.0.0.1:8085/BusinessSchema.MySqlSuite?suite

The FitNesse container connects to compose service `business-pgsql` or
`business-mysql`, user `test`, password `dbfit`, database `MyCo`. SQL Server
has no FitNesse suite.

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

That stops `business-pgsql`, `business-mysql`, `business-mssql`, and
`business-dbfit`. Named volumes stay. Other containers on the machine stay
as they are.

## Connect

Host tools use `127.0.0.1`. The FitNesse container uses the compose service
names, because those names resolve on the compose network.

### PostgreSQL

`business-pgsql` is `postgres:17` on `127.0.0.1:5432`. Database `MyCo`, user
`test`, password `dbfit`, schema `business`.

```
PGPASSWORD=dbfit psql -h 127.0.0.1 -U test MyCo
```

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

The image includes `sqlcmd`:

```
podman exec -it business-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U test -P dbfit -d MyCo
```

`-C` trusts the container certificate. A `sqlcmd` on the host uses the same
login with `-S 127.0.0.1`.

## Another database host

```
make pgsqldb PostgreSQLServer=<host>
make mysqldb MySQLServer=<host>
make sqlserverdb SQLServerServer=<host>
```

Any host other than `127.0.0.1` and `localhost` is used as given, and the
Makefile leaves the compose services alone. The target still drops and
reloads `MyCo` on that host.

## Another FitNesse

`make dbfit-stop` releases port 8085. Set `DBFIT_HOME` when the FitNesse
install used as the image build context is not `~/dbfit`.

The committed suite `Connect` rows use `business-pgsql` and `business-mysql`.
A FitNesse process outside the compose network needs a host it can resolve.
`127.0.0.1` reaches the published container ports. Leave machine-specific
hostnames out of the committed `SetUp` files.
