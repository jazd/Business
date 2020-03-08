namespace Business.Core.Fake
{
	public class Reader : IReader
	{
		string[] strings;
		bool IReader.HasRows => true;

		public Reader() {
		}

		public bool HasRows { get { return true; } }

		public void Add(string[] strings) {
			this.strings = strings;
		}
		public string GetString(int i) {
			return strings[i];
		}

		public bool Read() {
			return true;
		}
	}
}
