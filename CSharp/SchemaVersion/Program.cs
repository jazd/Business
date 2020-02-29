using System;
using Core;

namespace Version
{
    class MainClass
    {
        public static void Main(string[] args) {
            Console.WriteLine("Hello World!");
            var profile = new Profile();

            var database = new Core.SQLite.Database(profile);
            Console.WriteLine(database.Version());
        }
    }
}
