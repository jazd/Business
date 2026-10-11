#!/bin/bash
# Drop this user's tables before a reload. Run as db2inst1.
set -e
. ~/sqllib/db2profile
db2 connect to MYCO user test using dbfit
db2 -x "SELECT 'ALTER TABLE ' || RTRIM(TABNAME) || ' DROP CONSTRAINT ' || RTRIM(CONSTNAME) || ';' FROM SYSCAT.TABCONST WHERE TABSCHEMA = CURRENT SCHEMA AND TYPE = 'F'" > /tmp/db2-drop.sql || true
if grep -q 'DROP CONSTRAINT' /tmp/db2-drop.sql; then
  db2 -tvf /tmp/db2-drop.sql
fi
db2 -x "SELECT 'DROP TABLE ' || RTRIM(TABNAME) || ';' FROM SYSCAT.TABLES WHERE TABSCHEMA = CURRENT SCHEMA AND TYPE = 'T'" > /tmp/db2-drop.sql || true
if grep -q 'DROP TABLE' /tmp/db2-drop.sql; then
  db2 -tvf /tmp/db2-drop.sql
fi
db2 connect reset
