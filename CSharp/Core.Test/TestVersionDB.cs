using NUnit.Framework;

namespace Core.Test
{
    [TestFixture]
    public class TestVersionDB
    {
        [Test]
        public void NormalFullResult() {
            var profile = new Profile();

            var database = new Core.Fake.Database(profile);
            database.Add(new string[3] {"Business", "1.2.3", "4" });
            Assert.AreEqual("Business1.2.3-4", database.Version());
        }
    }
}
