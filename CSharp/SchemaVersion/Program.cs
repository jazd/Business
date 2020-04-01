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
			var individual = new Individual(database, 3);
			if (individual.FullName != null) {
				Console.WriteLine($"Author: {individual.FullName}");
			}
			Console.WriteLine(database.Book("Sale", 111.11F));
			database.Connection.Close();

			database = new Business.Core.PostgreSQL.Database(profile);
			Console.WriteLine($"PostgreSQL\t{database.SchemaVersion()}");
			individual = new Individual(database, 3);
			if (individual.FullName != null) {
				Console.WriteLine($"Author: {individual.FullName}");
			}
			Console.WriteLine(database.Book("Sale", 111.11F));
			database.Connection.Close();

			database = new Business.Core.NuoDB.Database(profile);
			Console.WriteLine($"NuoDB\t\t{database.SchemaVersion()}");
			individual = new Individual(database, 3);
			if (individual.FullName != null) {
				Console.WriteLine($"Author: {individual.FullName}");
			}
			Console.WriteLine(database.Book("Sale", 111.11F));
			database.Connection.Close();
		}
	}
}
