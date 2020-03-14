using System;

namespace Business.Core.Fake
{
	public class Reader : IReader
	{
		public Profile.Profile Profile { get; set; }
		public Exception ReaderGetException { get; set; }

		string[] strings;
		bool IReader.HasRows => true;

		public Reader() {
		}

		public bool HasRows { get { return true; } }

		public void Add(string[] strings) {
			this.strings = strings;
		}

		public string GetString(int i) {
			if (ReaderGetException != null) {
				Profile.Log.Error(ReaderGetException);
				throw ReaderGetException;
			}
			return strings[i];
		}

		public bool Read() {
			return true;
		}
	}
}
