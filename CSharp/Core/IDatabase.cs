using System;
using System.Collections.Generic;

namespace Business.Core
{
	public interface IDatabase
	{
		Profile.Profile Profile { get; set; }
		IConnection Connection { get; set; }
		ICommand Command { get; }

		String Type { get; }

		void Connect();

		Version SchemaVersion();

		// Server Side Functions
		UInt32? Book(string Name, float Amount);
		List<Balance> BookBalance(string Name, float Amount);
	}
}
