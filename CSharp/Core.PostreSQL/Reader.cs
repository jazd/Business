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
			if (PostgreSQLReader.IsDBNull(i))
				return null;
			return (UInt32?) PostgreSQLReader.GetInt32(i);
		}

		public bool? GetBoolean(int i) {
			if (PostgreSQLReader.IsDBNull(i))
				return null;
			return (bool?)PostgreSQLReader.GetBoolean(i);
		}

		public float? GetFloat(int i) {
			if (PostgreSQLReader.IsDBNull(i))
				return null;
			return (float?)Convert.ToDouble(PostgreSQLReader.GetValue(i));
		}

		public bool Read() {
			return PostgreSQLReader.Read();
		}

		public bool IsDBNull(int i) {
			return PostgreSQLReader.IsDBNull(i);
		}

		public void Dispose() {
			PostgreSQLReader.Dispose();
		}
	}
}
