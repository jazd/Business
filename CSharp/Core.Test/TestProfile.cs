using System;
using NUnit.Framework;
using Business.Core;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestProfile
	{
		[Test]
		public void Defaults() {
			Newtonsoft.Json.Linq.JObject JSON = Newtonsoft.Json.Linq.JObject.Parse(@"
{
  ""NoMatch"": {
		""Path"": ""business.sqlite3""
	}
}"
			);

			var profile = new Profile.Profile() { JSON = JSON };

			Assert.IsTrue(profile.SQLiteProfile.Active);
			Assert.IsTrue(profile.SQLiteProfile.Path.EndsWith(System.IO.Path.DirectorySeparatorChar + "business.sqlite3"));

			Assert.IsFalse(profile.NuoDBProfile.Active);
			Assert.AreEqual("nuodb", profile.NuoDBProfile.Server);
			Assert.AreEqual("MyCo", profile.NuoDBProfile.Database);
			Assert.AreEqual("test", profile.NuoDBProfile.User);
			Assert.AreEqual("secret", profile.NuoDBProfile.Password);

			Assert.IsFalse(profile.PostgreSQLProfile.Active);
			Assert.AreEqual("postgresql", profile.PostgreSQLProfile.Host);
			Assert.AreEqual("MyCo", profile.PostgreSQLProfile.Database);
			Assert.AreEqual("test", profile.PostgreSQLProfile.User);
		}

		[Test]
		public void FromJSON() {
			Newtonsoft.Json.Linq.JObject JSON = Newtonsoft.Json.Linq.JObject.Parse(@"
{
  ""SQLite"": {
		""Path"": ""MyCo/business.sqlite3""
	},
  ""NuoDb"": {
    ""Server"": ""localhost"",
    ""Database"": ""MyCo"",
    ""User"": ""test"",
    ""Password"": ""secret""
  },
  ""PostgreSQL"": {
    ""Host"": ""localhost"",
    ""Database"": ""MyCo"",
    ""User"": ""test""
  }
}"
			);

			var profile = new Profile.Profile() { JSON = JSON };

			Assert.IsTrue(profile.SQLiteProfile.Active);
			Assert.IsTrue(profile.SQLiteProfile.Path.EndsWith(System.IO.Path.DirectorySeparatorChar + "MyCo/business.sqlite3"));

			Assert.IsTrue(profile.NuoDBProfile.Active);
			Assert.AreEqual("localhost", profile.NuoDBProfile.Server);
			Assert.AreEqual("MyCo", profile.NuoDBProfile.Database);
			Assert.AreEqual("test", profile.NuoDBProfile.User);
			Assert.AreEqual("secret", profile.NuoDBProfile.Password);

			Assert.IsTrue(profile.PostgreSQLProfile.Active);
			Assert.AreEqual("localhost", profile.PostgreSQLProfile.Host);
			Assert.AreEqual("MyCo", profile.PostgreSQLProfile.Database);
			Assert.AreEqual("test", profile.PostgreSQLProfile.User);
		}

		[Test]
		public void FromFile() {
			var profile = new Profile.Profile();

			Assert.IsTrue(profile.SQLiteProfile.Active);
			Assert.IsTrue(profile.SQLiteProfile.Path.EndsWith(System.IO.Path.DirectorySeparatorChar + "business.sqlite3"));

			Assert.AreEqual("MyCo", profile.NuoDBProfile.Database);

			Assert.IsTrue(profile.PostgreSQLProfile.Active);
			Assert.AreEqual("postgresql", profile.PostgreSQLProfile.Host);
			Assert.AreEqual("MyCo", profile.PostgreSQLProfile.Database);
			Assert.AreEqual("test", profile.PostgreSQLProfile.User);

		}
	}
}
