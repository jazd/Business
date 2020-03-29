using System;
using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestDBFunctions
	{
		[Test]
		public void Book() {
			var profile = new Profile.Profile();
			var database = new Fake.Database(profile);
			database.Connect();

			var bookName = "Sales";
			float bookAmount = 111.11F;
			int? entryId = 1;

			database.SetValue(entryId);

			var entry = database.Book(bookName, bookAmount);

			Assert.IsNotNull(entry);
			Assert.Greater(entry, 0);
			Assert.AreEqual(entryId, entry);
		}
	}
}