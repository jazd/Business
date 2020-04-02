﻿using System;
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

		[Test]
		public void BookBalance() {
			var profile = new Profile.Profile();
			var database = new Fake.Database(profile);
			database.Connect();

			var bookName = "Sales";
			float bookAmount = 111.11F;

			var record1 = new object[] {
				(UInt32?)2,
				(UInt32?)1,
				(UInt32?)100,
				(UInt32?)76,
				"Cash",
				false,
				(UInt32?)70000,
				"Asset",
				100.00F,
				DBNull.Value
			};

			database.Add(record1);

			System.Collections.Generic.List<Balance> entry = database.BookBalance(bookName, bookAmount);
			Assert.IsTrue(database.Connection.TransactionStarted);
			Assert.IsFalse(database.Connection.TransactionRollback);
			Assert.IsTrue(database.Connection.TransactionCommited);
			Assert.IsTrue(database.Connection.Closed);

			Assert.Greater(entry.Count, 0);
			Assert.IsNotNull(entry[0].Entry);
			Assert.Greater(entry[0].Entry, 0);
			Assert.AreEqual(record1[1], entry[0].Entry);
		}
	}
}