using System;

namespace Business.Core.Fake
{
	public class Command : ICommand
	{
		public Profile.Profile Profile { get; set; }
		public Exception CommandException { get; set; }

		public Reader Reader { get; set; }
		public string CommandText { get; set; }

		public Command() {
			if (Reader == null)
				Reader = new Reader();
		}

		public IReader ExecuteReader() {
			// Database driver exceptions
			if (CommandException != null) {
				Profile.Log.Fatal(CommandException);
				throw CommandException;
			}

			return Reader;
		}
	}
}
