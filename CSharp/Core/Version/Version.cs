namespace Business.Core
{
    public class Version
    {
        public string Name { get; set; }
        public string Build { get; set; }
        public string Value { get; set; }
        public IDatabase Database { get; set; }

        public override string ToString() {
            if (Database != null)
                Get(Database, this);
            if (Value == null)
                return "0.0.0-Nil";
            if (Build == null)
                return Name + Value;
            else
                return Name + Value + "-" + Build;
        }

        public static Version Get(IDatabase database, Version version) {
            version.Database = database;
            version.Database.Connect();

            using (var connection = version.Database.Connection) {
                connection.Open();

                version.Database.Command.CommandText = @"
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

                var reader = version.Database.Command.ExecuteReader();
                if (reader.HasRows) {
                    if (reader.Read()) {
                        version.Name = reader.GetString(0);
                        version.Value = reader.GetString(1);
                        version.Build = reader.GetString(2);
                    }
                }

                connection.Close();

                return version;
            }
        }
    }
}
