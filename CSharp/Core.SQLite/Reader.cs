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

		public uint? GetInt32(int i) {
			throw new System.NotImplementedException();
		}

		public string GetString(int i) {
			return SQLiteReader.IsDBNull(i) ? null : SQLiteReader.GetString(i);
		}

		public bool IsDBNull(int i) {
			throw new System.NotImplementedException();
		}

		public bool Read() {
			return SQLiteReader.Read();
		}
	}
}
