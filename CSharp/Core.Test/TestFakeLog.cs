using System;
using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture()]
	public class TestFakeLog
	{
		private static Fake.Log log = new Fake.Log();
		private const string message = "something";
		private Exception exception;

		[SetUp]
		public void Init() {
			exception = new Exception(message);
		}

		[Test]
		public void Debug() {
			log.Debug(message);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Debug.ToString()));
			log.Debug(exception);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Debug.ToString()));
		}

		[Test]
		public void Info() {
			log.Info(message);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Info.ToString()));
			log.Info(exception);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Info.ToString()));
		}

		[Test]
		public void Warn() {
			log.Warn(message);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Warn.ToString()));
			log.Warn(exception);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Warn.ToString()));
		}

		[Test]
		public void
			Error() {
			log.Error(message);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Error.ToString()));
			log.Error(exception);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Error.ToString()));
		}

		[Test]
		public void
			Fatal() {
			log.Fatal(message);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
			log.Fatal(exception);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Fatal.ToString()));
		}

		[Test]
		public void
			Trace() {
			log.Trace(message);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Trace.ToString()));
			log.Trace(exception);
			Assert.That(log.Output, Contains.Substring(message));
			Assert.That(log.Output, Contains.Substring(Log.Level.Trace.ToString()));
		}
	}
}
