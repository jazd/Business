using System;
namespace Business.Core.SchemaVersion
{
    public class SchemaVersion
    {
        public static string Value(IDatabase database) {
            var version = new Version();

            if(database != null) {
                database.Connect();
            }

            return version.ToString();
        }
    }
}
