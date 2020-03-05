using Npgsql;

namespace Business.Core.PostgreSQL
{
    public class Command : ICommand
    {
        IReader Reader { get; set; }
        public NpgsqlConnection PostgreSQLConnection { get; set; }
        public NpgsqlCommand PostgreSQLCommand { get; set; }
        public NpgsqlDataReader PostgreSQLReader { get; set; }

        public Command() {
            PostgreSQLCommand = new NpgsqlCommand();
        }

        public string CommandText {
            get {
                return PostgreSQLCommand?.CommandText;
            }
            set {
                PostgreSQLCommand.CommandText = value;
            }
        }

        public IReader ExecuteReader() {
            PostgreSQLCommand.Connection = PostgreSQLConnection;
            PostgreSQLReader = PostgreSQLCommand.ExecuteReader();
            Reader = new Reader() { PostgreSQLReader = PostgreSQLReader };
            return Reader;
        }
    }
}
