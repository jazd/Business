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
	}
}
