.SUFFIXES:

.SUFFIXES: .pgsql .mysql .sqlite .db2 .sqlserver .oracle .sybase

.DEFAULT:
	@echo "Unknown target $@, try:  make help"

SQLT := /usr/local/bin/sqlt
SQLTBUILD :=

ifeq (,$(wildcard /usr/local/bin/sqlt))
	SQLTBUILD := podman build -t jazd/sqlt:dev -f Containerfile.sqlt .
	SQLT := podman run --rm -v $(CURDIR):/app:Z jazd/sqlt:dev sqlt
endif

# 127.0.0.1 and localhost start business-pgsql, business-mysql, and business-mssql.
# Any other host is used as given.
PostgreSQLServer = 127.0.0.1

MySQLServer = 127.0.0.1
MySQLPassword = -pdbfit

SQLServerServer = 127.0.0.1
# sa password meets the image policy. Login test uses dbfit with CHECK_POLICY off.
MSSQL_SA_PASSWORD = Dbfit_sa1

PGSQL_IS_CONTAINER := $(filter localhost 127.0.0.1,$(PostgreSQLServer))
MYSQL_IS_CONTAINER := $(filter localhost 127.0.0.1,$(MySQLServer))
MSSQL_IS_CONTAINER := $(filter localhost 127.0.0.1,$(SQLServerServer))
# sqlcmd in the 2022 image. -C trusts the container certificate.
SQLCMD = podman exec -w /work business-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -b

# FitNesse install used as the business-dbfit build context.
DBFIT_HOME ?= $(HOME)/dbfit
ifneq ($(PGSQL_IS_CONTAINER),)
PSQL_AUTH = PGPASSWORD=dbfit
else
PSQL_AUTH =
endif


ifeq ($(MySQLServer),)
MySQLServer = localhost
endif
ifeq ($(MySQLPassword),)
MySQLPassword =
endif

ifeq ($(DROP_TABLE),)
DROP_TABLE =
else
DROP_TABLE = --add-drop-table
endif

TARGETS = schema.pgsql schema.mysql schema.sqlite schema.db2 schema.sqlserver schema.oracle schema.sybase

all: $(TARGETS)

pgsql: schema.pgsql
mysql: schema.mysql
sqlite: schema.sqlite
db2: schema.db2
mssql: schema.sqlserver
oracle: schema.oracle
sybase: schema.sybase

schema.pgsql: schema.xml sqlt-cmd
	@echo Creating PostgreSQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t PostgreSQL $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/DROP TABLE /DROP TABLE IF EXISTS /g" | sed -e "s/DROP VIEW /DROP VIEW IF EXISTS /g" >> $@
	chmod -w $@

MYSQL_UNSUPORTED_VIEWS = People PeopleEvent Entities IndividualURL URL Sessions File TimePeriod Accounts Ledgers Books LedgerBalance LedgerReport EdgeIndividuals IndividualURL IndividualEmailAddress MaxSpan
schema.mysql: schema.xml sqlt-cmd
	@echo Creating MySQL file $@
	scripts/excludeView.pl $< $(MYSQL_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t MySQL $(DROP_TABLE) $<.excludeSomeViews | sed -e "s/\`//g" | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -E 's|([^_])exit|\1`exit`|g' | sed -e "s/'NOW()'/CURRENT_TIMESTAMP/g" | sed -e 's|lock|`lock`|g' | sed -E 's|([ \(])release([^_])|\1`release`\2|g' | sed -E 's/\sRelease([^_])/ `Release`\1/g' | sed -e 's|get text|`get` text|g' | sed -e "s/'false'/'0'/g" | sed -e "s/ interval / float /g" | sed -e 's|inet|varchar|g' | sed -e 's/WITHOUT TIME ZONE//g' | sed -e 's/integer integer/`integer` integer/g' | sed -e 's/float float/`float` float/g' | sed -e 's| schema | `schema` |g' | sed -e 's/get varchar/`get` varchar/g' | sed -e '/sentence_id_culture_value/ s/value)/value(256))/' | sed -e '/paragraph_id_culture_value/ s/value)/value(256))/' | sed -e 's/config integer NULL/config bigint(20) NULL/' | sed -e 's/birth timestamp/birth datetime/' | sed -e 's/nameChange timestamp/nameChange datetime/' | sed -e 's/death timestamp/death datetime/' >> $@
	chmod -w $@
	rm -f $<.excludeSomeViews

SQLITE_UNSUPORTED_VIEWS = TimePeriod Certificates
schema.sqlite: schema.xml sqlt-cmd
	@echo Creating SQLite file $@
	scripts/excludeView.pl $< $(SQLITE_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t SQLite $(DROP_TABLE) $<.excludeSomeViews | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/NOW()/CURRENT_TIMESTAMP/g" | sed -e "s/LEFT(number,3)/SUBSTR(number,1,3)/g" | sed -e "s/RIGHT(number,4)/SUBSTR(number,-4)/g" | sed -e "s/bool_AND/MIN/g" | sed -e "s/ClientCulture()/1033/g" | sed -e "/birthday(/d" | sed -e "/age(/d" >> $@
	sed -E '/^CREATE TABLE Word \(/,/^\);?$$/ { s/^  id integer NOT NULL,$$/  id integer NOT NULL DEFAULT 0,/; }' -i $@
	sed -E '/^CREATE TABLE Sentence \(/,/^\);?$$/ { s/^  id integer NOT NULL,$$/  id integer NOT NULL DEFAULT 0,/; }' -i $@
	sed -E '/^CREATE TABLE Paragraph \(/,/^\);?$$/ { s/^  id integer NOT NULL,$$/  id integer NOT NULL DEFAULT 0,/; }' -i $@
	sed -E '/^CREATE TABLE [A-Za-z0-9_]+ [(]/,/^[[:space:]]*[)];?[[:space:]]*(--.*)?$$/ { s/^[[:space:]]*id[[:space:]]+INTEGER[[:space:]]+PRIMARY[[:space:]]+KEY[[:space:]]+NOT[[:space:]]+NULL[[:space:]]*,?[[:space:]]*(--.*)?$$/  id INTEGER PRIMARY KEY AUTOINCREMENT,/; }' -i $@
	chmod -w $@
	rm -f $<.excludeSomeViews

schema.db2: schema.xml sqlt-cmd
	@echo Creating DB2 file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t DB2 $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

schema.sqlserver: schema.xml sqlt-cmd
	@echo Creating SQLServer file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t SQLServer $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/\[exit\]/ZexitZ/g" | sed -e "s/\[schema\]/ZschemaZ/g" | tr -d [] | sed -e "s/ZexitZ/\[exit\]/g" | sed -e "s/ZschemaZ/\[schema\]/g" | sed -e "s/NOW()/GETUTCDATE()/g" | sed -e "s/timestamp/datetime/g" | sed -e "s/false/0/g" | sed -e "s/datetime WITHOUT TIME ZONE/datetime2(6)/g" | sed -e "s/time WITHOUT TIME ZONE/time/g" | sed -e "s/interval/decimal(4,2)/g" | sed -e "s/bytea/varbinary/g" | sed -e "s/inet/varchar/g" | sed -e "s/boolean/bit/g" | sed -e "s/config integer NULL/config bigint NULL/" | sed -e "s/integer integer/[integer] integer/g" | sed -e "s/float float/[float] float/g" | sed -e "s/varchar NULL/varchar(max) NULL/g" | sed -e "s/varchar NOT NULL/varchar(max) NOT NULL/g" | sed -E "s/WHERE name = ([A-Za-z0-9_]+) AND type = U/WHERE name = '\1' AND type = 'U'/g" | sed -e '/^CREATE TABLE Part (/,/^);/ s/serial varchar(max)/serial varchar(800)/' | awk 'match($$0, /ADD CONSTRAINT ([^ ]+) FOREIGN KEY \(([^)]+)\)/, m) { name=m[1]; col=m[2]; if (seen[name]++) sub("ADD CONSTRAINT " name " ", "ADD CONSTRAINT " name "_" col " ") } { print }' >> $@
	chmod -w $@

schema.oracle: schema.xml sqlt-cmd
	@echo Creating Oracle file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t Oracle $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

schema.sybase: schema.xml sqlt-cmd
	@echo Creating Sybase file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t Sybase $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

clean:
	@echo Removing target files $(TARGETS)
	rm -f $(TARGETS)

touch-xml:
	@echo Force re-make of schema files
	@touch schema.xml

# sqlt-cmd builds the image only when /usr/local/bin/sqlt is absent.
sqlt-cmd:
	$(SQLTBUILD)

container: Containerfile.sqlt
	podman build -t jazd/sqlt:dev -f Containerfile.sqlt .

container-diagram: Containerfile.sqlt-diagram container
	podman build -t jazd/sqlt-diagram:dev -f Containerfile.sqlt-diagram .

dbfit: Containerfile.dbfit
	podman build -f Containerfile.dbfit -t localhost/jazd/dbfit:dev $(DBFIT_HOME)
	podman compose -f compose.dbfit.yml up -d business-dbfit

# PL/pgSQL sources live in PostgreSQL/procedures.d/ (ordered 00-99); assemble into procedures.sql
.PHONY: procedures
procedures: PostgreSQL/procedures.sql

PostgreSQL/procedures.sql: $(wildcard PostgreSQL/procedures.d/*.sql) scripts/assemble-pg-procedures.sh
	./scripts/assemble-pg-procedures.sh

pgsqldb: export DROP_TABLE = --add-drop-table
pgsqldb: touch-xml schema.pgsql PostgreSQL/procedures.sql
	@if [ -n "$(PGSQL_IS_CONTAINER)" ]; then podman compose -f compose.dbfit.yml up -d --wait business-pgsql; $(PSQL_AUTH) psql -h $(PostgreSQLServer) -U test -d MyCo -v ON_ERROR_STOP=1 -f PostgreSQL/container-init.sql; fi
	@echo Creating new PostgreSQL database with $@
	cat PostgreSQL/pre.sql schema.pgsql PostgreSQL/procedures.sql PostgreSQL/post.sql | $(PSQL_AUTH) psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null | grep ERROR || true
	cat Static/[01]_* | $(PSQL_AUTH) psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	awk -f scripts/USZip.awk Static/GeoNamesUSZipSample.tsv | awk -f scripts/PostalImportPostgreSQL.awk | $(PSQL_AUTH) psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	cat Static/[23456789]_* | $(PSQL_AUTH) psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null

sqlserverdb: export DROP_TABLE = --add-drop-table
sqlserverdb: touch-xml schema.sqlserver
	@if [ -n "$(MSSQL_IS_CONTAINER)" ]; then \
	  podman compose -f compose.dbfit.yml up -d --wait business-mssql && \
	  $(SQLCMD) -U sa -P $(MSSQL_SA_PASSWORD) -i /work/SQLServer/container-init.sql && \
	  echo Creating new SQLServer database with $@ && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/SQLServer/drop-fks.sql && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/schema.sqlserver && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/SQLServer/Statics.sql && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/SQLServer/views.sql && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/SQLServer/pre.sql && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/SQLServer/procedures.sql && \
	  $(SQLCMD) -U test -P dbfit -d MyCo -i /work/SQLServer/post.sql; \
	else \
	  echo To Create new SQLServer Database with $@; \
	  echo sqlcmd -S localhost -E -d MyCo -i schema.sqlserver; \
	  echo sqlcmd -S localhost -E -d MyCo -i SQLServer/Statics.sql; \
	  echo sqlcmd -S localhost -E -d MyCo -i SQLServer/views.sql; \
	  echo sqlcmd -S localhost -E -d MyCo -i SQLServer/procedures.sql; \
	  echo sqlcmd -S localhost -E -d MyCo -i SQLServer/post.sql; \
	fi

mysqldb: export DROP_TABLE = --add-drop-table
mysqldb: touch-xml schema.mysql
	@if [ -n "$(MYSQL_IS_CONTAINER)" ]; then podman compose -f compose.dbfit.yml up -d --wait business-mysql; fi
	@echo Creating new MySQL database with $@
	cat MySQL/pre.sql schema.mysql MySQL/procedures.sql MySQL/post.sql | mysql -h $(MySQLServer) -u test $(MySQLPassword) MyCo
	cat MySQL/0_TimeZone.sql |  mysql -h $(MySQLServer) -u test $(MySQLPassword) MyCo
	cat Static/[01]_[^T]* | sed -E 's/^--+[[:space:]]*/-- /' | sed -e "s/, false)/, '0')/g" -e "s/, true)/, '1')/g" | mysql -h $(MySQLServer) -u test $(MySQLPassword) MyCo
	cat Static/[23456789]_* | grep -v GetAddress | sed -E 's/^--+[[:space:]]*/-- /' | sed -e "s/, false)/, '0')/g" -e "s/, true)/, '1')/g" | mysql -h $(MySQLServer) -u test $(MySQLPassword) MyCo

# SQLite release template: same seed story as pgsqldb (Static + GeoNames sample)
# without PL/pgSQL. See scripts/build-business-sqlite3.sh.
.PHONY: rebuild-business-sqlite3
business.sqlite3: schema.sqlite scripts/build-business-sqlite3.sh scripts/PostalImportSQLite.awk scripts/USZip.awk SQLite/seed-addresses.sql
ifeq ($(wildcard business.sqlite3),)
	@echo Creating new SQLite database with $@
	./scripts/build-business-sqlite3.sh $@
else
	@echo SQLite database $@ already exists.
	@echo Please move or remove it, or: make rebuild-business-sqlite3
endif

rebuild-business-sqlite3: schema.sqlite
	@echo Rebuilding business.sqlite3 from schema + Static + GeoNames sample
	FORCE=1 ./scripts/build-business-sqlite3.sh business.sqlite3

# Shop SQLite hop (living while target unreleased). Example:
#   SQLITE_DB=$$HOME/business-shop/business.sqlite3 make upgrade-sqlite-0.2.13-0.2.14
# Stamp version when hop is complete: STAMP_VERSION=1 make ...
.PHONY: upgrade-sqlite-0.2.10-0.2.11 upgrade-sqlite-0.2.11-0.2.12 upgrade-sqlite-0.2.12-0.2.13 upgrade-sqlite-0.2.13-0.2.14
upgrade-sqlite-0.2.10-0.2.11:
	./scripts/upgrade-sqlite.sh 0.2.10 0.2.11
upgrade-sqlite-0.2.11-0.2.12:
	./scripts/upgrade-sqlite.sh 0.2.11 0.2.12
upgrade-sqlite-0.2.12-0.2.13:
	./scripts/upgrade-sqlite.sh 0.2.12 0.2.13
upgrade-sqlite-0.2.13-0.2.14:
	./scripts/upgrade-sqlite.sh 0.2.13 0.2.14
