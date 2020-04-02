// PostgreSQL IDatabase, IConnection, ICommand, IReader Wrapper
//
using System;
using System.Collections.Generic;
using Npgsql;

namespace Business.Core.PostgreSQL
{
	public class Database : IDatabase
	{
		public Profile.Profile Profile { get; set; }

		public Database(Profile.Profile profile) {
			Profile = profile;
		}

		public string Type => "PostgreSQL";

		NpgsqlConnection PostgreSQLConnection { get; set; }

		public IConnection Connection { get; set; }
		public ICommand Command { get; set; }

		void IDatabase.Connect() {
			PostgreSQLConnection = new NpgsqlConnection(
					$"Host={Profile?.PostgreSQLProfile.Host};Username={Profile?.PostgreSQLProfile.User};Database={Profile?.PostgreSQLProfile.Database}"
			);
			Connection = new Connection() { PostgreSQLConnection = PostgreSQLConnection };
			Command = new Command { PostgreSQLConnection = PostgreSQLConnection };
		}

		public Version SchemaVersion() {
			return Core.SchemaVersion.Get(this);
		}

		// Server-side functions
		public UInt32? Book(string Name, float Amount) {
			return Core.Function.Book(this, Name, Amount);
		}

		public List<Balance> BookBalance(string Name, float Amount) {
			throw new NotImplementedException();
		}
	}
}
