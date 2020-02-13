.SUFFIXES:

.SUFFIXES: .pgsql .mysql .sqlite .db2

.DEFAULT:
	@echo "Unknown target $@, try:  make help"

PostgreSQLServer = localhost

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

schema.nuodb: schema.xml
	@echo Creating NuoDB file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t NuoDB $(DROP_TABLE) $< | sed -e 's|["'\'']||g' | sed -e 's|lock|"lock"|g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "/--/d" | sed -e "s/CROSS /INNER /g" | sed -e "s/bool_AND/MIN/g" >> $@
	chmod -w $@

schema.mysql: schema.xml
	@echo Creating MySQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t MySQL $(DROP_TABLE) $< >> $@
	chmod -w $@

SQLITE_UNSUPORTED_VIEWS = IndividualPersonEvent PeopleEvent TimePeriod People Entities Accounts EdgeIndividuals
schema.sqlite: schema.xml
	@echo Creating SQLite file $@
	scripts/excludeView.pl $< $(SQLITE_UNSUPORTED_VIEWS) > $<.excludeSomeViews
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t SQLite $(DROP_TABLE) $<.excludeSomeViews | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/NOW()/CURRENT_TIMESTAMP/g" | sed -e "s/LEFT(number,3)/SUBSTR(number,1,3)/g" | sed -e "s/RIGHT(number,4)/SUBSTR(number,-4)/g" | sed -e "s/bool_AND/MIN/g" | sed -e "s/ClientCulture()/1033/g" >> $@
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

pgsqldb: export DROP_TABLE = --add-drop-table
pgsqldb: schema.pgsql
	@echo Creating new PostgreSQL database with $@
	cat PostgreSQL/pre.sql schema.pgsql PostgreSQL/procedures.sql PostgreSQL/post.sql | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null | grep ERROR || true
	cat Static/[01]_* | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	awk -f scripts/USZip.awk Static/GeoNamesUSZipSample.tsv | awk -f scripts/PostalImportPostgreSQL.awk | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	cat Static/[23456789]_* | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null

business.sqlite3: schema.sqlite
	@echo Creating new SQLite database with $@
	cat SQLite/pre.sql schema.sqlite | sqlite3 $@
	cat Static/[01]_* | sed -e "/GetInterval */d" | sqlite3 $@
	# TODO come up with GetPostal replacement
	# TODO come up with GetSentence and GetAddress replacements
	cat Static/[23456789]_* | sed -e "/GetSentence */d" | sed -e "/GetAddress */d" | sqlite3 $@
