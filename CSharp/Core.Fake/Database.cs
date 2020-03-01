
namespace Core.Fake
{
    public class Database : IDatabase
    {
        private Profile Profile;

        public Database(Profile profile) {
            this.Profile = profile;
        }

        public void Connect() {
        }

        public Version Version() {
            return new Version();
        }
    }

}
