Business
========
Business SQL Database schema

Virtually [CRUD]( http://en.wikipedia.org/wiki/Create,_read,_update_and_delete) free database schema with minimum business logic included.

Currently **Alpha**, and may change significantly before Beta release.  Use in this state **at your own risk**.

[Documentation](https://github.com/jazd/Business/wiki)

*Features*
* i18N from the start
* Extensive Test coverage
* Highly [normalized](http://en.wikipedia.org/wiki/Database_normalization)
* Common Views are included
* Records are almost never DELETEd
* Fields are almost never UPDATEd, and when they are, they have started out NULL
* Foreign Key fields tend to be the same name as the table they reference
* Field and table names are full words
* Procedures that always check for duplicates before insert
* Linking tables names are almost always composed of the [CamelCase](http://en.wikipedia.org/wiki/CamelCase) linked table names
* Queries read well
* Almost no business rules are carried out outside of the database server

The original idea for this schema comes from my earlier Origins/peopleSchema.sql work, a schema I created back in 2002.  Originally source controlled with RCS.
