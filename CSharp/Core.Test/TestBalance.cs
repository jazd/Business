using System;
using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestBalance
	{
		[Test]
		public void Value() {
			var record = new Balance() {
				RightSide = true,
				Debit = 10,
				Credit = 4
			};

			Assert.AreEqual(6, record.Value);
			record.Credit = null;
			Assert.AreEqual(10, record.Value);

			record = new Balance() {
				RightSide = false,
				Debit = 40,
				Credit = 100
			};

			Assert.AreEqual(60, record.Value);
			record.Debit = null;
			Assert.AreEqual(100, record.Value);
			record.Credit = null;
			Assert.AreEqual(0, record.Value);
		}

		[Test]
		// Get Value by account type from BookBalance result
		public void AccountTypeValue() {
			System.Collections.Generic.List<Balance> records = new System.Collections.Generic.List<Balance>();

			// BookBalance('Sale Jane Doe', 1000) results
			records.Add(new Balance() {
				Book = 20,
				Entry = 1,
				Account = 100,
				Name = "Cash",
				RightSide = false,
				Type = "Asset",
				Debit = 15050,
				Credit = 10300
			});
			records.Add(new Balance() {
				Book = 20,
				Entry = 1,
				Account = 102,
				Name = "Sales",
				RightSide = true,
				Type = "Income",
				Debit = null,
				Credit = 3300
			});
			records.Add(new Balance() {
				Book = 20,
				Entry = 1,
				Account = 200,
				Name = "Commissions Payable",
				RightSide = true,
				Type = "Liability",
				Debit = null,
				Credit = 750
			});

			Assert.AreEqual(4750, Balance.AccountTypeValue(records, "Asset"));
			Assert.AreEqual(3300, Balance.AccountTypeValue(records, "Income"));
			Assert.AreEqual(750,  Balance.AccountTypeValue(records, "Liability"));
		}

		[Test]
		// Get Value Sum by account types
		public void AccountTypeValues() {
			System.Collections.Generic.List<Balance> records = new System.Collections.Generic.List<Balance>();

			records.Add(new Balance() {
				Book = 20,
				Entry = 1,
				Account = 200,
				Name = "Commissions Payable",
				RightSide = true,
				Type = "Liability",
				Debit = null,
				Credit = 700
			});
			records.Add(new Balance() {
				Book = 20,
				Entry = 1,
				Account = 200,
				Name = "Taxes Payable",
				RightSide = true,
				Type = "Liability",
				Debit = null,
				Credit = 50
			});

			Assert.AreEqual(750, Balance.AccountTypeValue(records, "Liability"));
		}

	}
}
