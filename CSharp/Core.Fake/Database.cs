// Fake IDatabase, IConnection, ICommand, IReader Wrapper
//
using System;
using System.Net.Sockets;

namespace Business.Core.Fake
{
	public class Database : IDatabase
	{
		private Profile.Profile Profile;

		public Connection Connection { get; set; }

		public Command Command { get; set; }

		IConnection IDatabase.Connection { get => Connection; set => throw new NotImplementedException(); }
		ICommand IDatabase.Command => Command;

		public SocketException ConnectionException { get; set; }

		public Database(Profile.Profile profile) {
			this.Profile = profile;
		}

		public void Connect() {
			if (Connection == null)
				Connection = new Connection();
			if (Command == null)
				Command = new Command();

			if (Profile.Log != null && ConnectionException != null) {
				Profile.Log.Fatal(ConnectionException);
				throw ConnectionException;
			}
		}

		public Version SchemaVersion() {
			return Core.SchemaVersion.Get(this);
		}

		public void Add(string[] strings) {
			Command.Reader.Add(strings);
		}
	}

}
