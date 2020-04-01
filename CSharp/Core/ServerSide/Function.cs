using System;

namespace Business.Core
{
	public partial class Function
	{
		public static UInt32? Book(Core.IDatabase database, string name, float amount) {
			UInt32? entry = null;

			if (database != null) {
				database.Connect();
				database.Connection.Open();

				using (var transaction = database.Connection.BeginTransaction(System.Data.IsolationLevel.ReadCommitted)) {
					database.Command.CommandText = BookSQL;
					database.Command.Parameters.Add(new Parameter() {
						Name = "@book",
						Value = name
					});
					database.Command.Parameters.Add(new Parameter() {
						Name = "@amount",
						Value = amount
					});
					entry = (UInt32?)(int?)database.Command.ExecuteScalar();

					database.Connection.Commit();
				}
			}

			database.Connection.Close();
			return entry;
		}

		private const string BookSQL = @"
SELECT Book(@book, @amount) FROM DUAL;
";
	}
}
