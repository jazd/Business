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
	@echo $(ECHO) PostgreSQL file $@
	sqlt -f XML-SQLFairy -t PostgreSQL --add-drop-table $< | sed -e 's|["'\'']||g' > $@

schema.mysql: schema.xml
	@echo MySQL file $@
	sqlt -f XML-SQLFairy -t MySQL $< > $@

schema.sqlite: schema.xml
	@echo MySQL file $@
	sqlt -f XML-SQLFairy -t SQLite $< > $@

schema.db2: schema.xml
	@echo MySQL file $@
	sqlt -f XML-SQLFairy -t DB2 $< > $@

clean:
	@echo Removing target files $(TARGETS)
	rm -f $(TARGETS)

pgsqldb: schema.pgsql
	cat pgsql-pre.sql schema.pgsql static.sql pgsql-post.sql | psql -h localhost -U test MyCo
