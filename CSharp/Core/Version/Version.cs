using System;
namespace Core
{
    public class Version
    {
        public Version() { }

        public string Name { get; set; }
        public string Build { get; set; }
        public string Value { get; set; }
        public IDatabase Database { get; set; }

        public override string ToString() {
            if (Value == null)
                return "0.0.0-Nil";
            if (Build == null)
                return Name + Value;
            else
                return Name + Value + "-" + Build;
        }

        public static Version Get(IDatabase database) {
            var version = new Version() { Database = database };

            database.Connect();

            using (database.Connection) {
                database.Connection.Open();

                database.Command.CommandText = @"
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

                var reader = database.Command.ExecuteReader();
                if (reader.HasRows) {
                    reader.Read();
                    version.Name = reader.GetString(0);
                    version.Value = reader.GetString(1);
                    version.Build = reader.GetString(2);
                }

                database.Connection.Close();

                return version;
            }
        }
    }
}
