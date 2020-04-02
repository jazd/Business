// Fake IDatabase, IConnection, ICommand, IReader Wrapper
//
using System;
using System.Collections.Generic;
using System.Net.Sockets;

namespace Business.Core.Fake
{
	public class Database : IDatabase
	{
		public Profile.Profile Profile { get; set; }

		public Connection Connection { get; set; }

		public Command Command { get; set; }

		public string Type => "Fake";

		IConnection IDatabase.Connection { get => Connection; set => throw new NotImplementedException(); }
		ICommand IDatabase.Command => Command;

		public SocketException ConnectionException { get; set; }
		public Exception DatabaseException { get; set; }
		public Exception CommandException { get; set; }
		public Exception ReaderGetException { get; set; }

		public void SetValue(object value) {
			Command.Reader.SetValue(value);
		}

		public void Add(string[] strings) {
			Command.Reader.Add(strings);
		}

		public void Add(object[] objects) {
			Command.Reader.Add(objects);
		}

		public Database(Profile.Profile profile) {
			this.Profile = profile;
		}

		public void Connect() {
			if (Connection == null)
				Connection = new Connection() {
					Profile = Profile,
					ConnectionException = ConnectionException,
					DatabaseException = DatabaseException
				};

			if (Command == null)
				Command = new Command() {
					Profile = Profile,
					CommandException = CommandException,
					ReaderGetException = ReaderGetException
				};
		}

		public Version SchemaVersion() {
			return Core.SchemaVersion.Get(this);
		}

		// Server-side functions
		public UInt32? Book(string Name, float Amount) {
			return Core.Function.Book(this, Name, Amount);
		}

		public List<Balance> BookBalance(string Name, float Amount) {
			return Core.Function.BookBalance(this, Name, Amount);
		}
	}

}
