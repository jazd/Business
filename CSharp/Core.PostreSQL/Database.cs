﻿// PostgreSQL IDatabase, IConnection, ICommand, IReader Wrapper
//
using Npgsql;

namespace Business.Core.PostgreSQL
{
	public class Database : IDatabase
	{
		public Profile.Profile Profile { get; set; }

		public Database(Profile.Profile profile) {
			Profile = profile;
		}

		NpgsqlConnection PostgreSQLConnection { get; set; }

		public IConnection Connection { get; set; }
		public ICommand Command { get; set; }

		void IDatabase.Connect() {
			PostgreSQLConnection = new NpgsqlConnection(
					$"Host={Profile?.PostgreSQLProfile.Host};Username={Profile?.PostgreSQLProfile.User};Database={Profile?.PostgreSQLProfile.Database}");
			Connection = new Connection() { PostgreSQLConnection = PostgreSQLConnection };
			Command = new Command { PostgreSQLConnection = PostgreSQLConnection };
		}

		public Version SchemaVersion() {
			return Core.SchemaVersion.Get(this);
		}
	}
}
