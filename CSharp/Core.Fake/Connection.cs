using System;
using System.Net.Sockets;

namespace Business.Core.Fake
{
	public class Connection : IConnection, IDisposable
	{
	  public Profile.Profile Profile { get; set; }
		public SocketException ConnectionException { get; set; }

		public Connection() {
		}

		public void Open() {
			if (Profile.Log != null && ConnectionException != null) {
				Profile.Log.Fatal(ConnectionException);
				throw ConnectionException;
			}
		}

		public void Close() { }

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
}
