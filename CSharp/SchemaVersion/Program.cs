using System;
using Business.Core;

namespace Version
{
    class MainClass
    {
        public static void Main(string[] args) {
            Console.WriteLine("Hello World!");
            var profile = new Profile();
            var sqlitedatabase = new Business.Core.SQLite.Database(profile);
            Console.WriteLine($"SQLite\t\t{sqlitedatabase.Version()}");
            sqlitedatabase.Connection.Close();

            var pgsqldatabase = new Business.Core.PostgreSQL.Database(profile);
            Console.WriteLine($"PostgreSQL\t{pgsqldatabase.Version()}");
            pgsqldatabase.Connection.Close();
        }
    }
}
