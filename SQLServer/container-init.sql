-- Login test uses password dbfit. Schema Business is that login's default schema.
IF DB_ID(N'MyCo') IS NULL
BEGIN
  CREATE DATABASE MyCo;
END
GO
IF SUSER_ID(N'test') IS NULL
BEGIN
  CREATE LOGIN test WITH PASSWORD = N'dbfit', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
END
GO
USE MyCo;
GO
IF DATABASE_PRINCIPAL_ID(N'test') IS NULL
BEGIN
  CREATE USER test FOR LOGIN test;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Business')
BEGIN
  EXEC(N'CREATE SCHEMA Business AUTHORIZATION test');
END
GO
ALTER USER test WITH DEFAULT_SCHEMA = Business;
GO
IF NOT EXISTS (
  SELECT 1
  FROM sys.database_role_members AS m
  JOIN sys.database_principals AS r ON r.principal_id = m.role_principal_id
  JOIN sys.database_principals AS u ON u.principal_id = m.member_principal_id
  WHERE r.name = N'db_owner' AND u.name = N'test'
)
BEGIN
  ALTER ROLE db_owner ADD MEMBER test;
END
GO
