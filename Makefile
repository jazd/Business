.SUFFIXES:

.SUFFIXES: .pgsql .mysql .sqlite .db2

.DEFAULT:
	@echo "Unknown target $@, try:  make help"

PostgreSQLServer = localhost

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

TARGETS = schema.pgsql schema.mysql schema.sqlite schema.db2

ifeq ($(DROP_TABLE),)
DROP_TABLE =
else
DROP_TABLE = --add-drop-table
endif

all: schema.pgsql

pgsql: schema.pgsql
mysql: schema.mysql
sqlite: schema.sqlite
db2: schema.db2

schema.pgsql: schema.xml
	@echo Creating PostgreSQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t PostgreSQL $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/DROP TABLE /DROP TABLE IF EXISTS /g" | sed -e "s/DROP VIEW /DROP VIEW IF EXISTS /g" >> $@
	chmod -w $@

NUODB_UNSUPORTED_VIEWS = IndividualURL IndividualEmailAddress
schema.nuodb: schema.xml
	@echo Creating NuoDB file $@
	scripts/excludeView.pl $< $(NUODB_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t NuoDB $(DROP_TABLE) $<.excludeSomeViews | sed -e 's|["'\'']||g' | sed -e 's|lock|"lock"|g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "/--/d" | sed -e "s/CROSS /INNER /g" | sed -e "s/bool_AND/MIN/g" >> $@
	chmod -w $@
	rm -f $<.excludeSomeViews

schema.mysql: schema.xml
	@echo Creating MySQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t MySQL $(DROP_TABLE) $< >> $@
	chmod -w $@

SQLITE_UNSUPORTED_VIEWS = TimePeriod Accounts Ledgers Books LedgerBalance LedgerReport EdgeIndividuals IndividualURL IndividualEmailAddress
schema.sqlite: schema.xml
	@echo Creating SQLite file $@
	scripts/excludeView.pl $< $(SQLITE_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t SQLite $(DROP_TABLE) $<.excludeSomeViews | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/NOW()/CURRENT_TIMESTAMP/g" | sed -e "s/LEFT(number,3)/SUBSTR(number,1,3)/g" | sed -e "s/RIGHT(number,4)/SUBSTR(number,-4)/g" | sed -e "s/bool_AND/MIN/g" | sed -e "s/ClientCulture()/1033/g" | sed -e "/birthday(/d" | sed -e "/age(/d" >> $@
	chmod -w $@
	rm -f $<.excludeSomeViews

schema.db2: schema.xml
	@echo Creating DB2 file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t DB2 $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

schema.sqlserver: schema.xml
	@echo Creating SQLServer file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t SQLServer $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@


clean:
	@echo Removing target files $(TARGETS)
	rm -f $(TARGETS)

touch-xml:
	@echo Force re-make of schema files
	@touch schema.xml

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
