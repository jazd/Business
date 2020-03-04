using Microsoft.Data.Sqlite;

namespace Core.SQLite
{
    public class Command : ICommand
    {
        IReader Reader { get; set; }
        public SqliteConnection SQLiteConnection { get; set; }
        public SqliteCommand SQLiteCommand { get; set; }
        public SqliteDataReader SQLiteReader { get; set; }

        public Command() {
            SQLiteCommand = new SqliteCommand();
        }

        public string CommandText {
            get {
                return SQLiteCommand?.CommandText;
            }
            set {
                SQLiteCommand.CommandText = value;
            }
        }

        public IReader ExecuteReader() {
            SQLiteCommand.Connection = SQLiteConnection;
            SQLiteReader = SQLiteCommand.ExecuteReader();
            Reader = new Reader() { SQLiteReader = SQLiteReader };
            return Reader;
        }
    }
}
