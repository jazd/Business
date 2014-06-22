.SUFFIXES:

.SUFFIXES: .pgsql .mysql .sqlite .db2

.DEFAULT:
	@echo "Unknown target $@, try:  make help"

TARGETS = schema.pgsql schema.mysql schema.sqlite schema.db2

all: schema.pgsql

pgsql: schema.pgsql
mysql: schema.mysql
sqlite: schema.sqlite
db2: schema.db2

schema.pgsql: schema.xml
	@echo Creating PostgreSQL file $@
	sqlt -f XML-SQLFairy -t PostgreSQL --add-drop-table $< | sed -e 's|["'\'']||g' | sed -e "s/\!apos;/\'/g" | sed -e "s/\!lt;/\</g" | sed -e "s/\!gt;/\>/g"> $@

schema.mysql: schema.xml
	@echo Creating MySQL file $@
	sqlt -f XML-SQLFairy -t MySQL $< > $@

schema.sqlite: schema.xml
	@echo Creating MySQL file $@
	sqlt -f XML-SQLFairy -t SQLite $< > $@

schema.db2: schema.xml
	@echo Creating MySQL file $@
	sqlt -f XML-SQLFairy -t DB2 $< > $@

clean:
	@echo Removing target files $(TARGETS)
	rm -f $(TARGETS)

pgsqldb: schema.pgsql
	@echo Creating new PostgreSQL database with $@
	@echo Ignore: ERROR:  view \"*\" does not exist
	cat PostgreSQL/pre.sql schema.pgsql Static/*.sql PostgreSQL/post.sql | psql -h localhost -U test MyCo 3>&1 1>&2 2>&3 3>&- 1>/dev/null | grep ERROR || true
