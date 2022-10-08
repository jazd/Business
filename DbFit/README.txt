dbfit http://dbfit.github.io/dbfit/


PostgreSQL database schema test server setup
	Prior to version 10

As root
Add
local   MyCo            all                                     trust
host    MyCo            all             127.0.0.1/32            trust
host    MyCo            all             ::1/128                 trust
To /var/lib/pgsql/data/pg_hba.conf

Restart
/etc/init.d/postgresql restart

PostgreSQL database schema test server setup
	After version 9

su - postgres
mkdir -p postgres/data
initdb postgres/data
pg_ctl -D postgres/data -l logfile start

createdb -E UNICODE MyCo

psql MyCo
MyCo=#
CREATE USER test;
ALTER ROLE test WITH LOGIN;
CREATE SCHEMA Business;
GRANT ALL ON SCHEMA Business TO test;
ALTER USER test SET search_path TO Business;
\q

You may need to edit <git root>/Business/Makefile PostgreSQLServer host entry.

cd <git root>/Business
make pgsqldb

You may need to edit the Connect line in <git root>/Business/DbFit/BusinessSchema/PostgreSqlSuite/SetUp/content.txt

symbolic link <git root>/Business/DbFit/BusinessSchema to <dbfit install directory>/dbfit/FitNesseRoot/BusinessSchema
cd <dbfit install directory>
./startFitnesse.sh

http://localhost:8085/BusinessSchema

To edit a specific test
Add something like this to the top of the test page
!path lib/*.jar
!|dbfit.PostgresTest|
!|Connect|localhost|test|dbfit|MyCo|

For PostgreSQL tests
http://localhost:8085/BusinessSchema.PostgreSqlSuite?suite

Access the database directly
psql MyCo test


SQL Server Database Server

Enable the tcp/ip protocol using Sql Server Configuration Manager
Restart sqlserver

Create Database and allow username and password logins

sqlcmd -S localhost -E
> CREATE DATABASE MyCo;
> GO
> exec sp_configure 'contained database authentication', 1
> GO
> Reconfigure
> GO

> USE [master]
> GO
> ALTER DATABASE [MyCo] SET CONTAINMENT = PARTIAL
> GO
> USE [MyCo];
> GO
> CREATE SCHEMA Business
> GO
> CREATE USER test WITH PASSWORD = '<password>', DEFAULT_SCHEMA = Business;
> GO
> GRANT CONTROL ON schema :: dbo TO test;
> GO
> GRANT CONTROL ON schema :: Business TO test;
> QUIT

Verify login
sqlcmd -S localhost -U test -P <password> -d MyCo

Create Business Schema in SQL Server
sqlcmd -S localhost -E -d MyCo -i schema.sqlserver

sqlcmd -S localhost -E -d MyCo -i SQLServer\Statics.sql


Symbolic link  <git root>/Business/DbFit/BusinessSchema to <dbfit install directory>/dbfit/FitNesseRoot/BusinessSchema

mklink /D <dbfit install directory>\FitNessRoot\BusinessSchema <git root>\Business\DbFit\BusinessSchema

D:\Users\stevej\sandbox\Business\DbFit\BusinessSchema\SQLServerSuite>mklink /D TableTests ..\BusinessSuite\TableTests

Temporary fix to the test Queries so they work with SQL Server
find BusinessSchema/BusinessSuite/ -name content.txt -print0 | xargs -0 sed -i '/LIMIT 1/ s/SELECT /SELECT TOP 1 /;s/ LIMIT 1//'

cd <dbfit install directory>
./startFitnesse.bat

http://localhost:8085/BusinessSchema
