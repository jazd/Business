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

        public Profile() {
        }
    }
}
