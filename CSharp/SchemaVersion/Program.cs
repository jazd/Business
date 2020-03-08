using System;
using Business.Core;
using Business.Core.Profile;

namespace Version
{
    class MainClass
    {
        public static void Main(string[] args) {
            Console.WriteLine("Hello World!");
            var profile = new Profile();

            IDatabase database;

            database = new Business.Core.SQLite.Database(profile);
            Console.WriteLine($"SQLite\t\t{database.SchemaVersion()}");
            database.Connection.Close();

            database = new Business.Core.PostgreSQL.Database(profile);
            Console.WriteLine($"PostgreSQL\t{database.SchemaVersion()}");
            database.Connection.Close();

            database = new Business.Core.NuoDB.Database(profile);
            Console.WriteLine($"NuoDB\t\t{database.SchemaVersion()}");
            database.Connection.Close();
        }
    }
}
