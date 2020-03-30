using System;
namespace Business.Core
{
	public interface IConnection : IDisposable
	{
		void Open();
		void Close();
		IDisposable BeginTransaction(System.Data.IsolationLevel isolation);
		void Commit();
		void Rollback();
	}
}
