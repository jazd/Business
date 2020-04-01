using System;
namespace Business.Core
{
	public partial class Balance {
		public static Balance LoadFromReader(IReader reader) {
			Balance record = new Balance();
			return record;
		}
	}
}
