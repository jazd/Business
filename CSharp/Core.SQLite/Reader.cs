using Microsoft.Data.Sqlite;

namespace Core.SQLite
{
    public class Reader : IReader
    {
        public SqliteDataReader SQLiteReader { get; set; }

        public bool HasRows {
            get {
                return SQLiteReader.HasRows;
            }
        }

        public string GetString(int i) {
            return SQLiteReader.IsDBNull(i) ? null : SQLiteReader.GetString(i);
        }

        public void Read() {
            SQLiteReader.Read();
        }

    }
}
