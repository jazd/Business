using System.Data.Common;

namespace Business.Core.NuoDB
{
	public class Reader : IReader
	{
		public DbDataReader NuoDBReader { get; set; }

		public bool HasRows {
			get {
				// HasRows basically does not work with the NuoDB library, so almost always return true
				return NuoDBReader.FieldCount > 0;
			}
		}

		public uint? GetInt32(int i) {
			throw new System.NotImplementedException();
		}

		public string GetString(int i) {
			return NuoDBReader.IsDBNull(i) ? null : NuoDBReader.GetString(i);
		}

		public bool IsDBNull(int i) {
			throw new System.NotImplementedException();
		}

		public bool Read() {
			return NuoDBReader.Read();
		}
	}
}