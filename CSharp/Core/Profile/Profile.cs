using System;
using System.IO;

namespace Core
{
    public class Profile {
        public string DatabasePath {
            get {
                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal),
                    "sandbox/Business/business.sqlite3");
            }
        }

        public Profile(string databaseServer) {
        }
    }
}
