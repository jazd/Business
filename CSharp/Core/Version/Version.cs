namespace Business.Core
{
	public class Version
	{
		public string Name { get; set; }
		public string Build { get; set; }
		public string Value { get; set; }
		public IDatabase Database { get; set; }

		public override string ToString() {
			if (Database != null)
				SchemaVersion.Get(Database, this);
			if (Value == null)
				return "0.0.0-Nil";
			if (Build == null)
				return Name + Value;
			else
				return Name + Value + "-" + Build;
		}
	}
}
