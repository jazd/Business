using System;
using NUnit.Framework;
using Business.Core;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestBalanceDB
	{
		[Test]
		public void LoadFromReader() {
			Core.Fake.Reader reader = new Fake.Reader();

			var record = new object[] {
				2,
				1,
				100,
				76,
				"Cash",
				false,
				70000,
				"Asset",
				100.00F,
				DBNull.Value
			};

			reader.Add(record);

			var balanceRecord = Business.Core.Balance.LoadFromReader(reader);

			Assert.AreEqual(record[0],balanceRecord.Book);
			Assert.AreEqual(record[1], balanceRecord.Entry);
			Assert.AreEqual(record[2], balanceRecord.Account);
			Assert.AreEqual(record[3], balanceRecord.NameId);
			Assert.AreEqual(record[4], balanceRecord.Name);
			Assert.AreEqual(record[5], balanceRecord.RightSide);
			Assert.AreEqual(record[6], balanceRecord.TypeId);
			Assert.AreEqual(record[7], balanceRecord.Type);
			Assert.AreEqual(record[8], balanceRecord.Debit);
			Assert.IsNull(balanceRecord.Credit);
		}
	}
}
