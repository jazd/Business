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
			Assert.IsTrue(database.Connection.TransactionStarted);
			Assert.IsFalse(database.Connection.TransactionRollback);
			Assert.IsTrue(database.Connection.TransactionCommited);
			Assert.IsTrue(database.Connection.Closed);

			Assert.IsNotNull(entry);
			Assert.Greater(entry, 0);
			Assert.AreEqual(entryId, entry);
		}

		[Test]
		public void BookSQLite() {
			var profile = new Profile.Profile();
			var database = new Fake.Database(profile);
			database.Connect();

			var bookName = "Sales";
			float bookAmount = 111.11F;
			int? entryId = 1;

			database.SetValue(entryId);

			var entry = Function.SQLiteBook(database, bookName, bookAmount);
			Assert.IsTrue(database.Connection.TransactionStarted);
			Assert.IsFalse(database.Connection.TransactionRollback);
			Assert.IsTrue(database.Connection.TransactionCommited);
			Assert.IsTrue(database.Connection.Closed);

			Assert.IsNotNull(entry);
			Assert.Greater(entry, 0);
			Assert.AreEqual(entryId, entry);
		}
	}
}