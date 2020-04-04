using System;
using System.IO;

namespace Business.Core.Profile
{
	public class Profile
	{
		public ILog Log { get; set; }

		public string SQLiteDatabasePath {
			get {
				string path;

				if (string.IsNullOrEmpty(SQLiteProfile.Path))
					path = "sandbox/Business/business.sqlite3";
				else
					path = SQLiteProfile.Path;

				return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal), path);
			}
		}

		public SQLite SQLiteProfile {
			get {
				if (sqliteprofile == null) {
					var tokens = JSON["SQLite"];
					if (tokens != null) {
						sqliteprofile = tokens.ToObject<SQLite>();
						sqliteprofile.Active = true;
					} else {
						sqliteprofile = new SQLite();
					}
				}
				return sqliteprofile;
			}
		}
		SQLite sqliteprofile;

		public PostgreSQL PostgreSQLProfile {
			get {
				if(postgresqlprofile == null) {
					var tokens = JSON["PostgreSQL"];
					if(tokens != null) {
						postgresqlprofile = tokens.ToObject<PostgreSQL>();
						postgresqlprofile.Active = true;
					}
				}
				return postgresqlprofile;
			}
		}
		PostgreSQL postgresqlprofile;

		public NuoDB NuoDBProfile {
			get {
				if(nuodbprofile == null) {
					var tokens = JSON["NuoDb"];
					if (tokens != null) {
						nuodbprofile = tokens.ToObject<NuoDB>();
						nuodbprofile.Active = true;
					}
				}
				return nuodbprofile;
			}
		}
		NuoDB nuodbprofile;

		public string ProfilePath {
			get {
				return GetBasePath() + "profile.json";
			}
		}

		public Newtonsoft.Json.Linq.JObject JSON {
			get {
				if(json == null)
					json = Newtonsoft.Json.Linq.JObject.Parse(File.ReadAllText(ProfilePath));
				return json;
			}
			set {
				json = value;
			}
		}
		Newtonsoft.Json.Linq.JObject json;

		public Profile() {
		}

		public virtual string GetBasePath() {
			return AppDomain.CurrentDomain.RelativeSearchPath ?? AppDomain.CurrentDomain.BaseDirectory;
		}
	}

	public class SQLite
	{
		public Boolean Active { get; set; } = true;
		public string Path { get; set; }
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
