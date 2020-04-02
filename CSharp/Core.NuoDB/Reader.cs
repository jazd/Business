using System;
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

		public UInt32? GetInt32(int i) {
			if (NuoDBReader.IsDBNull(i))
				return null;
			return (UInt32?)NuoDBReader.GetInt32(i);
		}

		public string GetString(int i) {
			return NuoDBReader.IsDBNull(i) ? null : NuoDBReader.GetString(i);
		}

		public bool? GetBoolean(int i) {
			if (NuoDBReader.IsDBNull(i))
				return null;
			return (bool?)NuoDBReader.GetBoolean(i);
		}

		public float? GetFloat(int i) {
			if (NuoDBReader.IsDBNull(i))
				return null;
			return (float?)NuoDBReader.GetFloat(i);
		}

		public bool IsDBNull(int i) {
			return NuoDBReader.IsDBNull(i);
		}

		public bool Read() {
			return NuoDBReader.Read();
		}

		public void Dispose() {
			NuoDBReader.Dispose();
		}
	}
}
