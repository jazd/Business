-- Drop foreign keys so the generated DROP TABLE statements can run in any order.
DECLARE @sql nvarchar(max) = N'';
SELECT @sql += N'ALTER TABLE '
  + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + N'.'
  + QUOTENAME(OBJECT_NAME(parent_object_id))
  + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';'
FROM sys.foreign_keys;
IF @sql <> N''
  EXEC sp_executesql @sql;
GO
