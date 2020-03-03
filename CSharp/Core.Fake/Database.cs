// Fake IDatabase, IConnection, ICommand, IReader Wrapper
//
using System;

namespace Core.Fake
{
    public class Database : IDatabase {
        private Profile Profile;

        public IConnection Connection { get; set; }

        ICommand IDatabase.Command { get; }

        public Database(Profile profile) {
            this.Profile = profile;
        }

        public void Connect() {
            Connection = new Connection();
        }

        public Version Version() {
            return new Version();
        }

        String[] strings;
        public void Add(string[] strings) {
            this.strings = strings;
        }
    }

}
