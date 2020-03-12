using System;
using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture()]
	public class TestLog
	{
		private static ILog log = new Log();

		[Test()]
		public void Signatures() {
			string message = string.Empty;
			log.Debug(message);
			log.Info(message);
			log.Warn(message);
			log.Error(message);
			log.Fatal(message);
			log.Trace(message);

			Exception ex = new Exception();
			log.Debug(ex);
			log.Info(ex);
			log.Warn(ex);
			log.Error(ex);
			log.Fatal(ex);
			log.Trace(ex);
		}
	}
}
