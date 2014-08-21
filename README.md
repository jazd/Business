Business
========

Business SQL Database schema

Virtually CRUD free database.

Features
* I8N from the start
* Extensive Test coverage
* Highly normalized
* Records are almost never DELETEd
* Fields are almost never UPDATEd and when they are, they have started out NULL
* Reference fields tend to be the same name as the table they reference
* Field and table names are full words
* Procedures that always check for duplicates before insert, so no checks for existing records needed in code
* Linking tables names that are almost always composed of the linked table names
* Queries read well
* Almost no business rules are carried out outside of the database server

The original idea for this schema comes from my earlier Origins/peopleSchema.sql work, a schema I created back in 2002.  Orignally source controlled with RCS.
