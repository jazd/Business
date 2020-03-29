using System;
using System.Collections.Generic;

namespace Business.Core.Fake
{
	public class Command : ICommand
	{
		public Profile.Profile Profile { get; set; }
		public Exception CommandException { get; set; }
		public Exception ReaderGetException { get; set; }
		public List<Parameter> Parameters { get; set; }

		public Reader Reader {
			get {
				if (reader == null) {
					reader = new Reader() {
						Profile = Profile,
						ReaderGetException = ReaderGetException
					};
				}
				return reader;
			}
			set { reader = value; }
		}
		private Reader reader;

		public string CommandText { get; set; }

		public Command() {
			Parameters = new List<Parameter>();
		}

		public IReader ExecuteReader() {
			// Database driver exceptions
			if (CommandException != null) {
				Profile.Log.Fatal(CommandException);
				throw CommandException;
			}

			return Reader;
		}

		public object ExecuteScalar() {
			return Reader.Value;
		}
	}
}
