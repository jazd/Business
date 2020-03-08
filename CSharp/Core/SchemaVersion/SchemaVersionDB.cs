using System;
namespace Business.Core
{
    public class SchemaVersion
    {
        public static string Value(IDatabase database) {
            var version = new Version();

            if(database != null) {
                database.Connect();
            }

            return version.ToString();
        }

        public static Version Get(IDatabase database) {
            return Get(database, new Version());
        }

        public static Version Get(IDatabase database, Version version) {
            version.Database = database;
            version.Database.Connect();

            using (var connection = version.Database.Connection) {
                connection.Open();

                version.Database.Command.CommandText = SchemaVersionSQL;

                var reader = version.Database.Command.ExecuteReader();
                if (reader.HasRows) {
                    if (reader.Read()) {
                        version.Name  = reader.GetString(0);
                        version.Value = reader.GetString(1);
                        version.Build = reader.GetString(2);
                    }
                }

                connection.Close();

                return version;
            }
        }

        private const string SchemaVersionSQL = @"
SELECT Versions.name,
 Versions.value,
 Word.value AS build
FROM Versions, SchemaVersion
JOIN Word ON Word.id = SchemaVersion.build
AND Word.culture = 1033
WHERE Versions.version = SchemaVersion.version
ORDER BY SchemaVersion.build DESC
LIMIT 1
;";

    }
}
