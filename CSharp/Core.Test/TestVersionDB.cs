namespace Business.Core.Test
{
	[TestFixture]
	public class TestVersionDB
	{
		[Test]
		public void NormalFullResult() {
			var profile = new Profile.Profile();
			var database = new Fake.Database(profile);
			database.Connect();

			database.Add(new string[3] { "Business", "1.2.3", "4" });

			Assert.AreEqual("Business1.2.3-4", database.SchemaVersion().ToString());
		}

		[Test]
		public void NoResultFromDatabase() {
			var profile = new Profile.Profile();
			var database = new Fake.Database(profile);
			database.Connect();

			Assert.AreEqual("0.0.0-Nil", database.SchemaVersion().ToString());
		}

		[Test]
		public void DataReadError() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };
			var database = new Fake.Database(profile) {
				// Driver specific Exception
				ReaderGetException = new System.Exception("Before start of result set")
			};
			database.Connect();

			database.Add(new string[3] { "Business", "1.2.3", "4" });

			Assert.AreEqual("0.0.0-Nil", database.SchemaVersion().ToString());
			Assert.That(log.Output, Contains.Substring(Log.Level.Error.ToString()));
			Assert.That(log.Output, Contains.Substring("Before start"));
			Assert.That(log.Output, Contains.Substring("Version"));
		}
	}
}
