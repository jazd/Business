using System;
using System.IO;
using System.Collections.Generic;
using Newtonsoft;

namespace Business.Core.Profile
{
	public class Profile
	{
		public ILog Log { get; set; }

		public string SQLiteDatabasePath {
			get {
				return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal),
						"sandbox/Business/business.sqlite3");
			}
		}

		public SQLite SQLiteProfile { get; set; }
		public NuoDB NuoDBProfile { get; set; }
		public PostgreSQL PostgreSQLProfile { get; set; }

		public Profile() {
			SQLiteProfile = new SQLite();
			NuoDBProfile = new NuoDB();
			PostgreSQLProfile = new PostgreSQL();

			var filePath = GetBasePath() + "profile.json";
			try {
				Newtonsoft.Json.Linq.JObject profileJSON = Newtonsoft.Json.Linq.JObject.Parse(File.ReadAllText(filePath));

				var nuoDb = profileJSON["NuoDb"];
				if (nuoDb != null) {
					NuoDBProfile = nuoDb.ToObject<NuoDB>();
					NuoDBProfile.Active = true;
				}

				var postgreSQL = profileJSON["PostgreSQL"];
				if (postgreSQL != null) {
					PostgreSQLProfile = postgreSQL.ToObject<PostgreSQL>();
					PostgreSQLProfile.Active = true;
				}
			} catch {
				// Use the profile object defaults
			}
		}

		public static string GetBasePath() {
			return AppDomain.CurrentDomain.RelativeSearchPath ?? AppDomain.CurrentDomain.BaseDirectory;
		}
	}

	public class SQLite
	{
		public Boolean Active { get; set; } = true;
	}

	public class NuoDB
	{
		public Boolean Active { get; set; } = false;
		public string Server { get; set; } = "nuodb";
		public string Database { get; set; } = "MyCo";
		public string User { get; set; } = "test";
		public string Password { get; set; } = "secret";
	}

	public class PostgreSQL
	{
		public Boolean Active { get; set; } = false;
		public string Host { get; set; } = "postgresql";
		public string Database { get; set; } = "MyCo";
		public string User { get; set; } = "test";
	}
}
