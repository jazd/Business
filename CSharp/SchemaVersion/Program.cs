using System;
using Business.Core;

namespace Version
{
    class MainClass
    {
        public static void Main(string[] args) {
            Console.WriteLine("Hello World!");
            var profile = new Profile();

            var database = new Business.Core.SQLite.Database(profile);
            Console.WriteLine(database.Version());
        }
    }
}
