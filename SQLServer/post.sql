-- Application or user inserts on these tables should start well past static values
DBCC CHECKIDENT ('Word', RESEED, 2000000);
DBCC CHECKIDENT ('Name', RESEED, 2000000);
DBCC CHECKIDENT ('Entity', RESEED, 2000000);
DBCC CHECKIDENT ('Individual', RESEED, 4000000);
DBCC CHECKIDENT ('Given', RESEED, 2000000);
DBCC CHECKIDENT ('Family', RESEED, 2000000);
DBCC CHECKIDENT ('Email', RESEED, 2000000);
DBCC CHECKIDENT ('Path', RESEED, 2000000);
DBCC CHECKIDENT ('Application', RESEED, 10000);
DBCC CHECKIDENT ('Version', RESEED, 10000);
DBCC CHECKIDENT ('Release', RESEED, 10000);
DBCC CHECKIDENT ('ApplicationRelease', RESEED, 10000);
GO
