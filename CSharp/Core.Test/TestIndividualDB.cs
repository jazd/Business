using System;
using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture()]
	public class TestIndividualDB
	{
		[Test()]
		public void GetSingle() {
			var profile = new Profile.Profile();
			var database = new Fake.Database(profile);
			database.Connect();

			database.Add(new string[2] { "Stephen Arthur Jazdzewski", "Steve" });

			var individual = new Individual(database, 3);

			Assert.AreEqual(3, individual.Id);
			Assert.AreEqual(true, individual.Person);
			Assert.AreEqual("Steve", individual.GoesBy);
			Assert.AreEqual("Stephen Arthur Jazdzewski", individual.FullName);
		}
	}
}
