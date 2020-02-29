using System;
using Microsoft.Data.Sqlite;
using System.Collections.Generic;

namespace Core.SQLite
{
    public class Database : IDatabase
    {
        private Profile Profile;

        public Database(Profile profile) {
            this.Profile = profile;
        }

        SqliteConnection Connection { get; set; }
        SqliteCommand Command {
            get {
                if (command == null)
                    command = new SqliteCommand() { Connection = Connection };
                return command;

            }
        }
        SqliteCommand command;

        public void Connect () {
            Connection = new SqliteConnection($"Filename={Profile.SQLiteDatabasePath}");
        }

        public Version Version() {
            var version = new Version();

            Connect();

            using (Connection) {
                Connection.Open();

                Command.CommandText = @"
SELECT Versions.name,
 Versions.value,
 Word.value AS build
FROM Versions, SchemaVersion
JOIN Word ON Word.id = SchemaVersion.build
AND Word.culture = 1033
WHERE Versions.version = SchemaVersion.version
ORDER BY SchemaVersion.build DESC
LIMIT 1;";
                //// Just insert a part for quick testing
                //insertPart.CommandText = "INSERT INTO Part (name) VALUES (@NameId);";
                //insertPart.Parameters.AddWithValue("@NameId", 1);

                var reader = Command.ExecuteReader();
                if(reader.HasRows) {
                    reader.Read();
                    version.Name = reader.GetString(0);
                    version.Value = reader.GetString(1);
                    version.Build = reader.GetString(2);
                }

                Connection.Close();

                return version;
            }
        }
    }
}
