﻿using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestVersionDB
	{
		Fake.Database Database;
		[Test]
		public void NormalFullResult() {
			var profile = new Profile.Profile();

			var database = new Fake.Database(profile);
			database.Connect();

			database.Add(new string[3] { "Business", "1.2.3", "4" });
			Assert.AreEqual("Business1.2.3-4", database.SchemaVersion().ToString());
		}

		[Test]
		public void ExceptionLoggingHostname() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log } ;

			Database = new Fake.Database(profile);

			// Could not resolve host 'hostname'
			// https://docs.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2
			Database.ConnectionException = new System.Net.Sockets.SocketException(11001);
			Assert.Throws(typeof(System.Net.Sockets.SocketException), new TestDelegate(HostConnectOpenException));

			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			Assert.That(log.Output, Contains.Substring("host"));
		}

		[Test]
		public void ExceptionLoggingConnectionRefused() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			Database = new Fake.Database(profile);

			// Could not resolve host 'hostname'
			// https://docs.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2
			Database.ConnectionException = new System.Net.Sockets.SocketException(10061);
			Assert.Throws(typeof(System.Net.Sockets.SocketException), new TestDelegate(HostConnectOpenException));

			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			Assert.That(log.Output, Contains.Substring("refused"));
		}

		[Test]
		public void ExceptionLoggingDatabaseAuthenticationFailure() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			Database = new Fake.Database(profile);

			// Driver specific Exceptions
			Database.Exception = new System.Exception("Authentication failed");
			Assert.Throws(typeof(System.Exception), new TestDelegate(HostConnectOpenException));

			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			Assert.That(log.Output, Contains.Substring("Authentication failed"));
		}

		void HostConnectOpenException() {
			Database.Connect();
			Database.Connection.Open();
		}
	}
}
