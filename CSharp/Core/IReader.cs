using System;
namespace Business.Core
{
	public interface IReader
	{
		bool HasRows { get; }

		bool Read();
		void Dispose();
		Boolean IsDBNull(int i);
		string GetString(int v);
		UInt32? GetInt32(int i);
		Boolean? GetBoolean(int i);
		float? GetFloat(int i);
	}
}
