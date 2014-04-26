dbfit http://dbfit.github.io/dbfit/
PostgreSQL database schema test server setup

As root
Add
local   MyCo            all                                     trust
host    MyCo            all             127.0.0.1/32            trust
host    MyCo            all             ::1/128                 trust
To /var/lib/pgsql/data/pg_hba.comf

Restart
/etc/init.d/postgresql restart

As postres user
createdb -E UNICODE MyCo

psql MyCo
MyCo=# CREATE USER test WITH PASSWORD 'dbfit';
MyCo=# ALTER ROLE test WITH LOGIN;
MyCo=# CREATE SCHEMA Business;
MyCo=# GRANT ALL ON SCHEMA Business TO test;
MyCo=# ALTER USER test SET search_path TO Business;


symbolic link Business/DbFit/BusinessSchema to <dbfit install directory>/dbfit/FitNesseRoot

http://localhost:8085/BusinessSchema
Top of a test page
!path lib/*.jar
!|dbfit.PostgresTest|
!|Connect|localhost|test|dbfit|MyCo|

