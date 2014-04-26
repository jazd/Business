Business
========

Business SQL Database schema

Virtually CRUD free database.

TODO: List
* I8N from the start
* Almost 100% Test coverage
* Highly normalized
* Records are almost never DELETEd
* Fields are almost never UPDATEd and when they are they start out NULL
* References fields tend to be the name of the table they reference
* Field and table names are full words
* Always insert, no checks for existing fields before INSERT statement
* Linking tables almost always consist of the names of the tables that are linked
* Queries read well
* No schema rules carried out outside of the database server
