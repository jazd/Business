using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestFakeDatabase
	{
		[Test]
		public void NoResult() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			var database = new Fake.Database(profile);
			// No database.Add
			database.Connect();
			database.Connection.Open();
			database.Command.CommandText = "SELECT * FROM EMPTY_TABLE";
			var reader = database.Command.ExecuteReader();
			Assert.IsFalse(reader.HasRows);
		}
	}
}