// NuoDB IDatabase, IConnection, ICommand, IReader Wrapper
//
using NuoDb.Data.Client;

namespace Business.Core.NuoDB
{
    public class Database : IDatabase
    {
        private readonly Profile Profile;

        public Database(Profile profile) {
            Profile = profile;
        }

        NuoDbConnection NuoDBClientConnection { get; set; }

        public IConnection Connection { get; set; }
        public ICommand Command { get; set; }

        void IDatabase.Connect() {
            NuoDbConnectionStringBuilder builder = new NuoDbConnectionStringBuilder {
                Server = Profile?.NuoDBServer,
                Database = Profile?.NuoDBDatabase,
                User = Profile?.NuoDBUser,
                Password = Profile?.NuoDBPassword,
                Schema = Profile?.NuoDBSchema
            };

            NuoDBClientConnection = new NuoDbConnection(builder.ConnectionString);
            Connection = new Connection() { NuoDBClientConnection = NuoDBClientConnection };
            Command = new Command { NuoDBClientConnection = NuoDBClientConnection };
        }

        public Version Version() {
            return new Version() { Database = this };
        }
    }
}
