using System;
using Npgsql;

namespace Business.Core.PostgreSQL
{
	public class Reader : IReader
	{
		public NpgsqlDataReader PostgreSQLReader { get; set; }

		public bool HasRows {
			get {
				return PostgreSQLReader.HasRows;
			}
		}

		public string GetString(int i) {
			return PostgreSQLReader.IsDBNull(i) ? null : PostgreSQLReader.GetString(i);
		}

		public UInt32? GetInt32(int i) {
			if (HasRows && PostgreSQLReader.IsDBNull(i))
				return null;
			return (UInt32?) PostgreSQLReader.GetInt32(i);
		}

		public bool Read() {
			return PostgreSQLReader.Read();
		}

		public bool IsDBNull(int i) {
			throw new NotImplementedException();
		}
	}
}
