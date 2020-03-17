using System;
namespace Business.Core
{
	public partial class Individual
	{
		public UInt64? Id { get; set; }
		public Boolean? Person { get; set; }
		public String GoesBy { get; set; }
		public String FullName { get; set; }

		public Individual() { }

		private void Empty() { }
	}
}
