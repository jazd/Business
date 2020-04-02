using System;
using System.Collections.Generic;
namespace Business.Core
{
	public partial class Function {
		// Book single amounts into double entry Journal
		public static List<Balance> SQLiteBookBalance(Core.IDatabase database, string name, float amount) {
			List<Balance> result = new List<Balance>();

			database.Connection.Close();
			return result;
		}
	}
}
