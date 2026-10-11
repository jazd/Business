-- Schema business is the search_path set by PostgreSQL/pre.sql.
CREATE SCHEMA IF NOT EXISTS business AUTHORIZATION test;
ALTER ROLE test SET search_path TO business, public;
