using System;
using System.Collections.Generic;

namespace Business.Core
{
	public partial class Function
	{
		private const string BookSQL = @"
SELECT Book(@book, @amount) FROM DUAL;
";
		public static UInt32? Book(Core.IDatabase database, string name, float amount) {
			UInt32? entry = null;

			if (database != null) {
				database.Connect();
				database.Connection.Open();

				using (var transaction = database.Connection.BeginTransaction(System.Data.IsolationLevel.ReadCommitted)) {
					database.Command.TransactionText(transaction, BookSQL);
					database.Command.Parameters.Add(new Parameter() { Name = "@book", Value = name });
					database.Command.Parameters.Add(new Parameter() { Name = "@amount", Value = amount });
					entry = (UInt32?)(int?)database.Command.ExecuteScalar();

					database.Connection.Commit();
				}
			}

			database.Connection.Close();
			return entry;
		}

		private const string BookBalanceSQL = @"
		SELECT book, entry, account, nameid, name, rightSide, type AS typeId, typename AS type, debit, credit
		FROM BookBalance(@book, @amount);
		";
		public static List<Balance> BookBalance(Core.IDatabase database, string name, float amount) {
			List<Balance> result = new List<Balance>();

			if (database != null) {
				database.Connect();
				database.Connection.Open();

				using (var transaction = database.Connection.BeginTransaction(System.Data.IsolationLevel.ReadCommitted)) {
					database.Command.TransactionText(transaction, BookBalanceSQL);
					database.Command.Parameters.Add(new Parameter() { Name = "@book", Value = name });
					database.Command.Parameters.Add(new Parameter() { Name = "@amount", Value = amount });
					var reader = database.Command.ExecuteReader();
					if (reader.HasRows) {
						while (reader.Read()) {
							result.Add(Balance.LoadFromReader(reader));
						}
					}
					reader.Dispose();
					database.Connection.Commit();
				}
			}

			database.Connection.Close();
			return result;
		}
	}
}