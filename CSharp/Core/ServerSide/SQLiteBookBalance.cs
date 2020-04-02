using System;
using System.Collections.Generic;
namespace Business.Core
{
	public partial class Function {
		// Book single amounts into double entry Journal
		public static List<Balance> SQLiteBookBalance(Core.IDatabase database, string name, float amount) {
			List<Balance> result = new List<Balance>();
			// Book the amount
			var entry = SQLiteBook(database, name, amount);

			// Report on current book balances
			// TODO don't close in SQLiteBook call
			database.Connection.Open();
			database.Command.CommandText = ReportJournalEntryBalancesSQL;
			database.Command.Parameters.Clear();
			database.Command.Parameters.Add(new Parameter() { Name = "@book", Value = name });
			database.Command.Parameters.Add(new Parameter() { Name = "@entry", Value = entry });
			database.Command.Parameters.Add(new Parameter() { Name = "@clientCulture", Value = 1033 });
			var reader = database.Command.ExecuteReader();
			if(reader.HasRows) {
				while(reader.Read()) {
					result.Add(Balance.LoadFromReader(reader));
				}
			}
			reader.Dispose();
			database.Connection.Close();
			return result;
		}

		// Parameter @book, @entry, @clientCulture
		private const string ReportJournalEntryBalancesSQL = @"
SELECT BookName.book,
 @entry AS entry,
 Transactions.account,
 AccountName.name AS nameId,
 AccountNameString.value AS name,
 AccountName.credit AS rightside,
 AccountName.type,
 Word.value AS typeName,
 SUM(Transactions.debit) AS debit,
 SUM(transactions.credit) AS credit
FROM (
 SELECT JournalEntry.account,
  CASE WHEN NOT JournalEntry.credit THEN
   JournalEntry.amount
  END AS debit,
  CASE WHEN JournalEntry.credit THEN
   JournalEntry.amount
  END AS credit
 FROM JournalEntry
 WHERE JournalEntry.account IN (
  SELECT DISTINCT JournalEntry.account
  FROM JournalEntry
  WHERE JournalEntry.entry = @entry
   AND posted IS NULL
 ) AND JournalEntry.posted IS NULL
) AS Transactions
JOIN AccountName ON AccountName.account = Transactions.account
JOIN Word ON Word.id = AccountName.type
 AND Word.culture = @clientCulture
JOIN Sentence AS AccountNameString ON AccountNameString.id = AccountName.name
 AND AccountNameString.culture = @clientCulture
JOIN Sentence AS BookNameString ON BookNameString.value = @book
 AND BookNameString.culture = 1033 -- Identity
JOIN BookName ON BookName.name = BookNameString.id
GROUP BY Transactions.account, AccountName.name, AccountName.credit, AccountName.type, Word.value, AccountNameString.value
";
	}
}
