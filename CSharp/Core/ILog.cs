using System;
namespace Business.Core
{
	public interface ILog
	{
		void Debug(string message);
		void Debug(Exception ex);
		void Info(string message);
		void Info(Exception ex);
		void Warn(string message);
		void Warn(Exception ex);
		void Error(string message);
		void Error(Exception ex);
		void Fatal(string message);
		void Fatal(Exception ex);
		void Trace(string message);
		void Trace(Exception ex);
	}
}
