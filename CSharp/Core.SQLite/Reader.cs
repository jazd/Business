using System;
using Microsoft.Data.Sqlite;

namespace Business.Core.SQLite
{
	public class Reader : IReader
	{
		public SqliteDataReader SQLiteReader { get; set; }

		public bool HasRows {
			get {
				return SQLiteReader.HasRows;
			}
		}

		public UInt32? GetInt32(int i) {
			if(SQLiteReader.IsDBNull(i))
				return null;
			return (UInt32?)SQLiteReader.GetInt32(i);
		}

		public string GetString(int i) {
			return SQLiteReader.IsDBNull(i) ? null : SQLiteReader.GetString(i);
		}

		public bool? GetBoolean(int i) {
			if (SQLiteReader.IsDBNull(i))
				return null;
			return (bool?)SQLiteReader.GetBoolean(i);
		}

		public float? GetFloat(int i) {
			if (SQLiteReader.IsDBNull(i))
				return null;
			return (float?)SQLiteReader.GetFloat(i);
		}

		public bool IsDBNull(int i) {
			return SQLiteReader.IsDBNull(i);
		}

		public bool Read() {
			return SQLiteReader.Read();
		}

		public void Dispose() {
			SQLiteReader.Dispose();
		}
	}
}
