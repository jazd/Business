using NUnit.Framework;
using System;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestFakeDBReader
	{
		object[] record = {
				DBNull.Value,
				(UInt32?)32,
				"String",
				false,
				100.00F
		};

		Fake.Reader reader = new Fake.Reader();

		[SetUp]
		public void Setup() {
			reader.Add(record);
		}
		[Test]
		public void GetString() {
			Assert.IsTrue(reader.IsDBNull(0));
			Assert.IsEmpty(reader.GetString(0));
			Assert.AreEqual("String", reader.GetString(2));
		}
		[Test]
		public void GetInt32() {
			Assert.AreEqual(32, reader.GetInt32(1));
		}

		[Test]
		public void GetBoolean() {
			Assert.AreEqual(false, reader.GetBoolean(3));
		}

		[Test]
		public void GetFloat() {
			Assert.AreEqual(100.00F, reader.GetFloat(4));
		}
	}
}
