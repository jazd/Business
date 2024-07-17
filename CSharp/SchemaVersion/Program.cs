using System;
using System.Collections.Generic;
using Business.Core;
using Business.Core.Profile;

namespace Version
{
	class MainClass
	{

		public static void Main(string[] args) {
			var profile = new Profile();

			// For each database connection enabled in Profile, execute the same application code
			foreach (var database in Databases(profile)) {
				Console.WriteLine($"{database.Type}\t\t{database.SchemaVersion()}");
#if DEBUG
				// Sample database agnostic objects classes and function calls
				// Objects
				var individual = new Individual(database, 3);
				if (individual.FullName != null) {
					Console.WriteLine($"Author: {individual.FullName}");
				}

				// Database Functions
				Console.WriteLine(database.Book("Sale", 111.11F));

				Console.WriteLine(
					Balance.AccountTypeValue(
						database.BookBalance("Sale", 111.11F),
						"Income"
					)
				);
#endif
			}
		}

		public static List<IDatabase> Databases(Profile profile) {
			var databases = new List<IDatabase>();
			if (profile.SQLiteProfile.Active)
				databases.Add(new Business.Core.SQLite.Database(profile));
			if (profile.PostgreSQLProfile.Active)
				databases.Add(new Business.Core.PostgreSQL.Database(profile));
			return databases;
		}
	}
}
