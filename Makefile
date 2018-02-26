.SUFFIXES:

.SUFFIXES: .pgsql .mysql .sqlite .db2

.DEFAULT:
	@echo "Unknown target $@, try:  make help"

PostgreSQLServer = localhost

TARGETS = schema.pgsql schema.mysql schema.sqlite schema.db2

all: schema.pgsql

pgsql: schema.pgsql
mysql: schema.mysql
sqlite: schema.sqlite
db2: schema.db2

schema.pgsql: schema.xml
	@echo Creating PostgreSQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t PostgreSQL --add-drop-table $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

schema.nuodb: schema.xml
	@echo Creating NuoDB file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t NuoDB --add-drop-table $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "/--/d" | sed -e "s/CROSS /INNER /g" >> $@
	chmod -w $@

schema.mysql: schema.xml
	@echo Creating MySQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t MySQL --add-drop-table $< >> $@
	chmod -w $@

schema.sqlite: schema.xml
	@echo Creating MySQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t SQLite --add-drop-table $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" | sed -e "s/NOW()/CURRENT_TIMESTAMP/g" | sed -e "s/LEFT(number,3)/SUBSTR(number,1,3)/g" | sed -e "s/RIGHT(number,4)/SUBSTR(number,-4)/g" >> $@
	chmod -w $@

schema.db2: schema.xml
	@echo Creating MySQL file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t DB2 --add-drop-table $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@

schema.sqlserver: schema.xml
	@echo Creating SQLServer file $@
	if [[ -e $@ ]]; then chmod +w $@; fi
	sed 's/^/-- /' LICENSE.txt > $@
	sqlt -f XML-SQLFairy -t SQLServer --add-drop-table $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g" | sed -e "s/!amp;/\&/g" >> $@
	chmod -w $@


clean:
	@echo Removing target files $(TARGETS)
	rm -f $(TARGETS)

pgsqldb: schema.pgsql
	@echo Creating new PostgreSQL database with $@
	@echo Ignore: ERROR:  view \"*\" does not exist
	cat PostgreSQL/pre.sql schema.pgsql PostgreSQL/procedures.sql PostgreSQL/post.sql | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null | grep ERROR || true
	cat Static/[01]_* | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	awk -f scripts/USZip.awk Static/GeoNamesUSZipSample.tsv | awk -f scripts/PostalImportPostgreSQL.awk | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
	cat Static/[23456789]_* | psql -h $(PostgreSQLServer) -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null
