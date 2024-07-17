namespace Business.Core.Test
{

	[TestFixture]
	public class TestVersion
	{
		[Test]
		public void Empty() {
			var version = new Version();
			Assert.AreEqual("0.0.0-Nil", version.ToString());
		}

		[Test]
		public void NullValue() {
			var version = new Version { Name = "Business", Build = "203" };
			Assert.AreEqual("0.0.0-Nil", version.ToString());

		}

		[Test]
		public void NullName() {
			var version = new Version { Value = "2.3.4", Build = "1" };
			Assert.AreEqual("2.3.4-1", version.ToString());
		}

		[Test]
		public void NullBuild() {
			var version = new Version { Value = "2.3.4", Name = "Business" };
			Assert.AreEqual("Business2.3.4", version.ToString());
		}

	}
}
