// Fake IDatabase, IConnection, ICommand, IReader Wrapper
//
using System;

namespace Core.Fake
{
    public class Database : IDatabase
    {
        private Profile Profile;

        public Connection Connection { get; set; }

        public Command Command { get; set; }

        IConnection IDatabase.Connection { get => Connection; set => throw new NotImplementedException(); }
        ICommand IDatabase.Command => Command;

        public Database(Profile profile) {
            this.Profile = profile;
        }

        public void Connect() {
            if (Connection == null)
                Connection = new Connection();
            if (Command == null)
                Command = new Command();
        }

        public Version Version() {
            return new Version() { Database = this };
        }

        public void Add(string[] strings) {
            Command.Reader.Add(strings);
        }
    }

}
