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

        public IConnection Connection { get; internal set; }
        public ICommand Command { get; internal set; }

        public string GetString(int i) {
            return SQLiteReader.GetString(i);
        }

        public void Read() {
            SQLiteReader.Read();
        }

    }
}
