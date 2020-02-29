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

        public void Connect () {
            Connection = new SqliteConnection($"Filename={Profile.DatabasePath}");
        }

        public Version Version() {
            Connect();

            using (Connection) {
                Connection.Open();

                SqliteCommand insertPart = new SqliteCommand() { Connection = Connection };

                // Just insert a part for quick testing
                insertPart.CommandText = "INSERT INTO Part (name) VALUES (@NameId);";
                insertPart.Parameters.AddWithValue("@NameId", 1);

                insertPart.ExecuteReader();

                Connection.Close();

                return new Version();
            }
        }
    }
}
