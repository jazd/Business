using System;
using System.IO;

namespace Business.Core
{
    public class Profile {
        public string SQLiteDatabasePath {
            get {
                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal),
                    "sandbox/Business/business.sqlite3");
            }
        }

        public string PostgreSQLHost { get { return "postgresql"; } }
        public string PostgreSQLDatabase { get { return "MyCo"; } }
        public string PostgreSQLUser { get { return "test"; } }

        public Profile() {
        }
    }
}
