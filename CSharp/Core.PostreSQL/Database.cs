// PostgreSQL IDatabase, IConnection, ICommand, IReader Wrapper
//
using Npgsql;

namespace Business.Core.PostgreSQL
{
    public class Database : IDatabase
    {
        private readonly Profile Profile;

        public Database(Profile profile) {
            Profile = profile;
        }

        NpgsqlConnection PostgreSQLConnection { get; set; }

        public IConnection Connection { get; set; }
        public ICommand Command { get; set; }

        void IDatabase.Connect() {
            PostgreSQLConnection = new NpgsqlConnection(
                $"Host={Profile?.PostgreSQLHost};Username={Profile?.PostgreSQLUser};Database={Profile?.PostgreSQLDatabase}");
            Connection = new Connection() { PostgreSQLConnection = PostgreSQLConnection };
            Command = new Command { PostgreSQLConnection = PostgreSQLConnection };
        }

        public Version Version() {
            return new Version() { Database = this };
        }
    }
}
