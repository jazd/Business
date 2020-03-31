﻿using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestFakeDatabase
	{
		Fake.Log log;
		Profile.Profile profile;
		Fake.Database database;

		[SetUp]
		public void Setup() {
			log = new Core.Fake.Log();
			profile = new Profile.Profile() { Log = log };
			database = new Fake.Database(profile);
			database.Connect();
			database.Connection.Open();
		}

		[Test]
		public void NoResult() {
			// No database.Add
			database.Command.CommandText = "SELECT * FROM EMPTY_TABLE";
			var reader = database.Command.ExecuteReader();
			Assert.IsFalse(reader.HasRows);
		}

		[Test]
		public void DatabaseType() {
			Assert.AreEqual("Fake", database.Type);
		}

		[Test]
		public void Parameters() {
			database.Command.CommandText = "SELECT * FROM AnyTable WHERE id = @id and b = @b";
			database.Command.Parameters.Add(new Parameter() { Name = "@id", Value = 3 });
			database.Command.Parameters.Add(new Parameter() { Name = "@b", Value = 6 });
		}

		[Test]
		public void Transactions() {

		}
	}
}