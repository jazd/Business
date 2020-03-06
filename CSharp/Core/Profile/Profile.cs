using System;
using System.IO;

namespace Business.Core
{
    public class Profile
    {
        public string SQLiteDatabasePath {
            get {
                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal),
                    "sandbox/Business/business.sqlite3");
            }
        }

        public string PostgreSQLHost { get { return "postgresql"; } }
        public string PostgreSQLDatabase { get { return "MyCo"; } }
        public string PostgreSQLUser { get { return "test"; } }

        public string NuoDBServer { get { return "nuodb"; } }
        public string NuoDBDatabase { get { return "MyCo"; } }
        public string NuoDBUser { get { return "test"; } }
        public string NuoDBPassword { get { return "secret"; } }
        public string NuoDBSchema { get { return "Business"; } }

        public Profile() {
        }
    }
}
