// Fake IDatabase, IConnection, ICommand, IReader Wrapper
//
using System;
using System.Net.Sockets;

namespace Business.Core.Fake
{
	public class Database : IDatabase
	{
		private Profile.Profile Profile { get; set; }

		public Connection Connection { get; set; }

		public Command Command { get; set; }

		IConnection IDatabase.Connection { get => Connection; set => throw new NotImplementedException(); }
		ICommand IDatabase.Command => Command;

		public SocketException ConnectionException { get; set; }
		public Exception Exception { get; set; }

		public Database(Profile.Profile profile) {
			this.Profile = profile;
		}

		public void Connect() {
			if (Connection == null)
				Connection = new Connection() {
					Profile = Profile,
					ConnectionException = ConnectionException,
					Exception = Exception
				};
			if (Command == null)
				Command = new Command();
		}

		public Version SchemaVersion() {
			return Core.SchemaVersion.Get(this);
		}

		public void Add(string[] strings) {
			Command.Reader.Add(strings);
		}
	}

}
