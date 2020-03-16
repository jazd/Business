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

		[Test]
		public void DatabaseType() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			var database = new Fake.Database(profile);
			Assert.AreEqual("Fake", database.Type);
		}

		[Test]
		public void Parameters() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			var database = new Fake.Database(profile);
			// No database.Add
			database.Connect();
			database.Connection.Open();
			database.Command.CommandText = "SELECT * FROM AnyTable WHERE id = @id and b = @b";
			database.Command.Parameters.Add(new Parameter() { Name = "@id", Value = 3 });
			database.Command.Parameters.Add(new Parameter() { Name = "@b", Value = 6 });
		}
	}
}