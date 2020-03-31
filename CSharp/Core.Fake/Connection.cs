using System;
using System.Data;
using System.Net.Sockets;

namespace Business.Core.Fake
{
	public class Connection : IConnection, IDisposable
	{
		public Profile.Profile Profile { get; set; }
		public SocketException ConnectionException { get; set; }
		public Exception DatabaseException { get; set; }
		public bool? TransactionStarted { get; set; }
		public bool? TransactionCommited { get; set; }
		public bool? TransactionRollback { get; set; }
		public bool? Closed { get; set; }

		public Connection() {
			TransactionStarted = false;
			TransactionCommited = false;
			TransactionRollback = false;
			Closed = false;
		}

		public void Open() {
			if (Profile?.Log != null) {
				// Socket exceptions
				if (ConnectionException != null) {
					Profile.Log.Fatal(ConnectionException);
					throw ConnectionException;
				}

				// Database driver exceptions
				if (DatabaseException != null) {
					Profile.Log.Fatal(DatabaseException);
					throw DatabaseException;
				}

				Closed = false;
			}
		}

		public void Close() {
			Closed = true;
		}

		public IDisposable BeginTransaction(IsolationLevel isolation) {
			TransactionStarted = true;
			TransactionCommited = false;
			TransactionRollback = false;
			return new Trasaction();
		}

		public void Commit() {
			TransactionCommited = true;
		}

		public void Rollback() {
			TransactionRollback = true;
		}

		#region IDisposable Support
		private bool disposedValue = false; // To detect redundant calls

		protected virtual void Dispose(bool disposing) {
			if (!disposedValue) {
				if (disposing) {
					// TODO: dispose managed state (managed objects).
				}

				// TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
				// TODO: set large fields to null.

				disposedValue = true;
			}
		}

		// TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
		// ~Connection() {
		//   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
		//   Dispose(false);
		// }

		// This code added to correctly implement the disposable pattern.
		public void Dispose() {
			// Do not change this code. Put cleanup code in Dispose(bool disposing) above.
			Dispose(true);
			// TODO: uncomment the following line if the finalizer is overridden above.
			// GC.SuppressFinalize(this);
		}
		#endregion
	}

	class Trasaction : IDbTransaction
	{
		public IDbConnection Connection => throw new NotImplementedException();

		public IsolationLevel IsolationLevel => throw new NotImplementedException();

		public void Commit() {
			throw new NotImplementedException();
		}

		public void Rollback() {
			throw new NotImplementedException();
		}

		#region IDisposable Support
		private bool disposedValue = false; // To detect redundant calls

		protected virtual void Dispose(bool disposing) {
			if (!disposedValue) {
				if (disposing) {
					// TODO: dispose managed state (managed objects).
				}

				// TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
				// TODO: set large fields to null.

				disposedValue = true;
			}
		}

		// TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
		// ~Trasaction()
		// {
		//   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
		//   Dispose(false);
		// }

		// This code added to correctly implement the disposable pattern.
		public void Dispose() {
			// Do not change this code. Put cleanup code in Dispose(bool disposing) above.
			Dispose(true);
			// TODO: uncomment the following line if the finalizer is overridden above.
			// GC.SuppressFinalize(this);
		}
		#endregion
	}
}
