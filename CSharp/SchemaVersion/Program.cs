using System;
using Business.Core.Profile;

namespace Version
{
    class MainClass
    {
        public static void Main(string[] args) {
            Console.WriteLine("Hello World!");
            var profile = new Profile();
            var sqlitedatabase = new Business.Core.SQLite.Database(profile);
            Console.WriteLine($"SQLite\t\t{sqlitedatabase.SchemaVersion()}");
            sqlitedatabase.Connection.Close();

            var pgsqldatabase = new Business.Core.PostgreSQL.Database(profile);
            Console.WriteLine($"PostgreSQL\t{pgsqldatabase.SchemaVersion()}");
            pgsqldatabase.Connection.Close();

            var nuodbdatabase = new Business.Core.NuoDB.Database(profile);
            Console.WriteLine($"NuoDB\t\t{nuodbdatabase.SchemaVersion()}");
            nuodbdatabase.Connection.Close();
        }
    }
}
