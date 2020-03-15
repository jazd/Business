using System;
namespace Business.Core
{
	public interface IDatabase
	{
		Profile.Profile Profile { get; set; }
		IConnection Connection { get; set; }
		ICommand Command { get; }

		void Connect();
		Version SchemaVersion();
	}
}
