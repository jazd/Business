.SUFFIXES:

.SUFFIXES: .pgsql .mysql .sqlite .db2

.DEFAULT:
	@echo "Unknown target $@, try:  make help"

SQLT := /usr/local/bin/sqlt
SQLTBUILD :=

ifeq (,$(wildcard /usr/local/bin/sqlt))
	SQLTBUILD := podman build -t jazd/sqlt:dev -f Containerfile.sqlt .
	SQLT := podman run -v $(CURDIR):/app:Z jazd/sqlt:dev sqlt
endif

PostgreSQLServer = localhost

ifeq ($(MySQLServer),)
MySQLServer = localhost
endif
ifeq ($(MySQLPassword),)
MySQLPassword =
endif

ifeq ($(NuoDBDatabase),)
NuoDBDatabase = MyCo
endif
ifeq ($(NuoDBServer),)
NuoDBServer = localhost
endif
ifeq ($(NuoDBUser),)
NuoDBUser = dba
endif
ifeq ($(NuoDBPassword),)
NuoDBPassword = secret
endif

NuoSQLCommand = nuosql $(NuoDBDatabase)@$(NuoDBServer) --user $(NuoDBUser) --password $(NuoDBPassword) --schema Business --connection-property timezone=Etc/GMT
NuoDBLoad = $(NuoSQLCommand) 3>&1 1>&2 2>&3 3>&- 1>/dev/null

ifeq ($(DROP_TABLE),)
DROP_TABLE =
else
DROP_TABLE = --add-drop-table
endif

TARGETS = schema.pgsql schema.mysql schema.sqlite schema.db2

all: $(TARGETS)

pgsql: schema.pgsql
mysql: schema.mysql
sqlite: schema.sqlite
db2: schema.db2

schema.pgsql: schema.xml container
	@echo Creating PostgreSQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t PostgreSQL $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/DROP TABLE /DROP TABLE IF EXISTS /g" | sed -e "s/DROP VIEW /DROP VIEW IF EXISTS /g" >> $@
	chmod -w $@

NUODB_UNSUPORTED_VIEWS = IndividualURL IndividualEmailAddress
schema.nuodb: schema.xml container
	@echo Creating NuoDB file $@
	scripts/excludeView.pl $< $(NUODB_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t NuoDB $(DROP_TABLE) $<.excludeSomeViews | sed -e 's|["'\'']||g' | sed -e 's|lock|"lock"|g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "/--/d" | sed -e "s/CROSS /INNER /g" | sed -e "s/bool_AND/MIN/g" >> $@
	chmod -w $@
	rm -f $<.excludeSomeViews

MYSQL_UNSUPORTED_VIEWS = People PeopleEvent Entities IndividualURL URL Sessions File TimePeriod Accounts Ledgers Books LedgerBalance LedgerReport EdgeIndividuals IndividualURL IndividualEmailAddress MaxSpan
schema.mysql: schema.xml container
	@echo Creating MySQL file $@
	scripts/excludeView.pl $< $(MYSQL_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t MySQL $(DROP_TABLE) $<.excludeSomeViews | sed -e "s/\`//g" | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -E 's|([^_])exit|\1`exit`|g' | sed -e "s/'NOW()'/CURRENT_TIMESTAMP/g" | sed -e 's|lock|`lock`|g' | sed -E 's|([ \(])release([^_])|\1`release`\2|g' | sed -E 's/\sRelease([^_])/ `Release`\1/g' | sed -e 's|get text|`get` text|g' | sed -e "s/'false'/'0'/g" | sed -e "s/ interval / float /g" | sed -e 's|inet|varchar|g' | sed -e 's/WITHOUT TIME ZONE//g' | sed -e 's/integer integer/`integer` integer/g' | sed -e 's/float float/`float` float/g' | sed -e 's| schema | `schema` |g' | sed -e 's/get varchar/`get` varchar/g' | sed -e '/sentence_id_culture_value/ s/value)/value(256))/' | sed -e '/paragraph_id_culture_value/ s/value)/value(256))/' >> $@
	chmod -w $@

SQLITE_UNSUPORTED_VIEWS = TimePeriod Accounts Ledgers Books LedgerBalance LedgerReport EdgeIndividuals IndividualURL IndividualEmailAddress
schema.sqlite: schema.xml container
	@echo Creating SQLite file $@
	scripts/excludeView.pl $< $(SQLITE_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t SQLite $(DROP_TABLE) $<.excludeSomeViews | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/NOW()/CURRENT_TIMESTAMP/g" | sed -e "s/LEFT(number,3)/SUBSTR(number,1,3)/g" | sed -e "s/RIGHT(number,4)/SUBSTR(number,-4)/g" | sed -e "s/bool_AND/MIN/g" | sed -e "s/ClientCulture()/1033/g" | sed -e "/birthday(/d" | sed -e "/age(/d" >> $@
	chmod -w $@
	rm -f $<.excludeSomeViews

schema.db2: schema.xml container
	@echo Creating DB2 file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t DB2 $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

schema.sqlserver: schema.xml container
	@echo Creating SQLServer file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	$(SQLT) -f XML-SQLFairy -t SQLServer $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/\[exit\]/ZexitZ/g" | sed -e "s/\[schema\]/ZschemaZ/g" | tr -d [] | sed -e "s/ZexitZ/\[exit\]/g" | sed -e "s/ZschemaZ/\[schema\]/g" | sed -e "s/NOW()/GETUTCDATE()/g" | sed -e "s/timestamp/datetime/g" | sed -e "s/false/'false'/g" | sed -e "s/datetime WITHOUT TIME ZONE/datetime2(6)/g" | sed -e "s/time WITHOUT TIME ZONE/time/g" | sed -e "s/interval/decimal(4,2)/g" | sed -e "s/bytea/varbinary/g" | sed -e "s/inet/varchar/g" | sed -e "s/boolean/bit/g" >> $@
	chmod -w $@


clean:
	@echo Removing target files $(TARGETS)
	rm -f $(TARGETS)

touch-xml:
	@echo Force re-make of schema files
	@touch schema.xml

container: Containerfile.sqlt
	$(SQLTBUILD)

pgsqldb: export DROP_TABLE = --add-drop-table
pgsqldb: touch-xml schema.pgsql
	@echo Creating new PostgreSQL database with $@
	cat PostgreSQL/pre.sql schema.pgsql PostgreSQL/procedures.sql PostgreSQL/post.sql | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null | grep ERROR || true
	cat Static/[01]_* | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	awk -f scripts/USZip.awk Static/GeoNamesUSZipSample.tsv | awk -f scripts/PostalImportPostgreSQL.awk | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	cat Static/[23456789]_* | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null

nuodbdb: export DROP_TABLE = --add-drop-table
nuodbdb: touch-xml schema.nuodb
	@echo Creating new NuoDB database with $@
	cat NuoDB/pre.sql schema.nuodb NuoDB/procedures.sql NuoDB/post.sql | $(NuoDBLoad)
	cat Static/[01]_* |  $(NuoDBLoad)
	awk -f scripts/USZip.awk Static/GeoNamesUSZipSample.tsv | awk -f scripts/PostalImportPostgreSQL.awk | $(NuoDBLoad)
	cat Static/[23456789]_* | $(NuoDBLoad)

sqlserverdb: export DROP_TABLE = --add-drop-table
sqlserverdb: touch-xml schema.sqlserver
	@echo To Create new SQLServer Database with $@
	@echo sqlcmd -S localhost -E -d MyCo -i schema.sqlserver
	@echo sqlcmd -S localhost -E -d MyCo -i SQLServer/Statics.sql
	@echo sqlcmd -S localhost -E -d MyCo -i SQLServer/views.sql
	@echo sqlcmd -S localhost -E -d MyCo -i SQLServer/procedures.sql
	@echo sqlcmd -S localhost -E -d MyCo -i SQLServer/post.sql

mysqldb: export DROP_TABLE = --add-drop-table
mysqldb: touch-xml schema.mysql
	@echo Creating new MySQL database with $@
	cat MySQL/pre.sql schema.mysql MySQL/procedures.sql | mysql -h $(MySQLServer) -u test $(MySQLPassword) Business
	cat MySQL/0_TimeZone.sql |  mysql -h $(MySQLServer) -u test $(MySQLPassword) Business
	cat Static/[01]_[^T]* |  mysql -h $(MySQLServer) -u test $(MySQLPassword) Business
	cat Static/[23456789]_* | grep -v GetAddress | mysql -h $(MySQLServer) -u test $(MySQLPassword) Business

business.sqlite3: schema.sqlite
ifeq ($(wildcard business.sqlite3),)
	@echo Creating new SQLite database with $@
	cat SQLite/pre.sql schema.sqlite | sqlite3 $@
	cat Static/[01]_* | sed -e "/GetInterval */d" | sqlite3 $@
	# TODO come up with GetPostal replacement
	# TODO come up with GetSentence and GetAddress replacements
	cat Static/[23456789]_* | sed -e "/GetSentence */d" | sed -e "/GetAddress */d" | sed -e "s/, false/, 0/g" | sed -e "s/, true/, 1/g" | sqlite3 $@
else
	@echo SQLite database $@ already exists.
	@echo Please move or remove it.
endif
