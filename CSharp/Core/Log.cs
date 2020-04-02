using System;
namespace Business.Core
{
	public class Log : ILog
	{
		public enum Level
		{
			Trace = 0,
			Debug = 1,
			Info = 5,
			Warn = 6,
			Error = 10,
			Fatal = 11
		}

		private void Write(Level level, string message) {
			Console.WriteLine($"{level} {message}");
		}

		private void Write(Level level, Exception exception) {
			Console.WriteLine($"{level} {exception}");
		}

		public void Debug(string message) {
			Write(Level.Debug, message);
		}

		public void Debug(Exception exception) {
			Write(Level.Debug, exception);
		}

		public void Error(string message) {
			Write(Level.Error, message);
		}

		public void Error(Exception exception) {
			Write(Level.Error, exception);
		}

		public void Fatal(string message) {
			Write(Level.Fatal, message);
		}

		public void Fatal(Exception exception) {
			Write(Level.Fatal, exception);
		}

		public void Info(string message) {
			Write(Level.Info, message);
		}

		public void Info(Exception exception) {
			Write(Level.Info, exception);
		}

		public void Trace(string message) {
			Write(Level.Trace, message);
		}

		public void Trace(Exception exception) {
			Write(Level.Trace, exception);
		}

		public void Warn(string message) {
			Write(Level.Warn, message);
		}

		public void Warn(Exception exception) {
			Write(Level.Warn, exception);
		}
	}
}
