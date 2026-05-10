Business
========

**Open Source Business SQL Database Schema**

Created with SQLFairy sqlt from an XML file as the source. It targets PostgreSQL, MySQL, SQLite and others.

A virtually [CRUD]( http://en.wikipedia.org/wiki/Create,_read,_update_and_delete) free database schema with minimum business logic included.

Tested with DbFit at dbfit.github.com/dbfit

This schema keeps a full history of all changes. Instead of editing or deleting old records, the design adds new records. This approach preserves every past state of the data.

**Current status:** Alpha. The design may change significantly before the Beta release. Use in this state at your own risk.

A couple of the supported SQL servers:
- [PostgreSQL](https://github.com/jazd/Business/releases/latest/download/schema.pgsql) DDL
  - You will also need procedures.sql, pre.sql and post.sql
- [MySQL](https://github.com/jazd/Business/releases/latest/download/schema.mysql) DDL
- [SQLite database](https://github.com/jazd/Business/releases/latest/download/business.sqlite3) (pre-built)

[Documentation and examples](https://github.com/jazd/Business/wiki): https://github.com/jazd/Business/wiki

**Features**
* i18n support from the start
* Extensive test coverage
* Highly [normalized](http://en.wikipedia.org/wiki/Database_normalization)
* Common VIEWs are included
* Records are almost never DELETEd
* Fields are almost never UPDATEd. When they are, they start out as NULL
* Foreign key fields tend to use the same name as the table they reference
* Field and table names are full words
* Procedures always check for duplicates before insert
* Linking table names are almost always composed of the [CamelCase](http://en.wikipedia.org/wiki/CamelCase) names of the linked tables
* Queries read well
* Almost no business rules are carried out outside of the database server

The original idea for this schema comes from my earlier Origins/peopleSchema.sql work. I created that schema back in 2002. It was originally source controlled with RCS.

Optional
- perl-XML-Twig (Fedora: `sudo dnf install perl-XML-Twig`)
- podman (Fedora: `sudo dnf install podman podman-docker podman-compose`)
