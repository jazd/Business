using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture]
	public class TestFakeDatabaseExceptions
	{
		Fake.Database Database;

		[Test]
		public void Hostname() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			Database = new Fake.Database(profile);

			// Could not resolve host 'hostname'
			// https://docs.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2
			Database.ConnectionException = new System.Net.Sockets.SocketException(11001);
			Assert.Throws(typeof(System.Net.Sockets.SocketException), new TestDelegate(HostConnectOpenException));

			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			Assert.That(log.Output, Contains.Substring("host"));
		}

		[Test]
		public void ConnectionRefused() {
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
		public void AuthenticationFailure() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			Database = new Fake.Database(profile);

			// Driver specific Exception
			Database.DatabaseException = new System.Exception("Authentication failed");
			Assert.Throws(typeof(System.Exception), new TestDelegate(HostConnectOpenException));

			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			Assert.That(log.Output, Contains.Substring("Authentication failed"));
		}

		[Test]
		public void CantFindTable() {
			var log = new Core.Fake.Log();
			var profile = new Profile.Profile() { Log = log };

			// Driver specific Exception
			Database = new Fake.Database(profile);
			Database.CommandException = new System.Exception("can't find table \"VERSIONS\"");
			Database.Connect();
			Database.Connection.Open();

			Assert.Throws(typeof(System.Exception), new TestDelegate(ExecuteReaderException));

			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			Assert.That(log.Output, Contains.Substring("VERSIONS"));
		}

		void HostConnectOpenException() {
			Database.Connect();
			Database.Connection.Open();
		}

		void ExecuteReaderException() {
			Database.Command.CommandText = "";

			Database.Command.ExecuteReader();
		}
	}
}
