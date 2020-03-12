using System;
namespace Business.Core.Fake
{
	public class Log : ILog
	{
		public String Output { get; set; }

		private void Write(Core.Log.Level level, String message) {
			Output = $"{level} {message}";
		}

		private void Write(Core.Log.Level level, Exception exception) {
			Output = $"{level}, {exception.Message}";
		}


		public void Debug(string message) {
			Write(Core.Log.Level.Debug, message);
		}

		public void Debug(Exception exception) {
			Write(Core.Log.Level.Debug, exception);
		}

		public void Error(string message) {
			Write(Core.Log.Level.Error, message);
		}

		public void Error(Exception exception) {
			Write(Core.Log.Level.Error, exception);
		}

		public void Fatal(string message) {
			Write(Core.Log.Level.Fatal, message);
		}

		public void Fatal(Exception exception) {
			Write(Core.Log.Level.Fatal, exception);
		}

		public void Info(string message) {
			Write(Core.Log.Level.Info, message);
		}

		public void Info(Exception exception) {
			Write(Core.Log.Level.Info, exception);
		}

		public void Trace(string message) {
			Write(Core.Log.Level.Trace, message);
		}

		public void Trace(Exception exception) {
			Write(Core.Log.Level.Trace, exception);
		}

		public void Warn(string message) {
			Write(Core.Log.Level.Warn, message);
		}

		public void Warn(Exception exception) {
			Write(Core.Log.Level.Warn, exception);
		}
	}
}
