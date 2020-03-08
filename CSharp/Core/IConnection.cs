using System;
namespace Business.Core
{
	public interface IConnection : IDisposable
	{
		void Open();
		void Close();
	}
}
