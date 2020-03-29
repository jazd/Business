﻿using System;
namespace Business.Core
{
	public partial class Function
	{
    // Book single amounts into double entry Journal
    public static UInt32? SQLiteBook(Core.IDatabase database, string name, float amount) {
			UInt32? entry = null;
      UInt32? book = null;

			database.Connect();
			database.Connection.Open();

      // TODO must be done inside a transaction
      //      test Fake transactions first

      // Get Id of Book
      database.Command.CommandText = GetBookIdSQL;
      database.Command.Parameters.Add(new Parameter() { Name = "@book", Value = name });
      book = System.Convert.ToUInt32(
        database.Command.ExecuteScalar()
      );

      // Create new Entry
			// Insert Entry record
      database.Command.CommandText = GetEntryIdSQL;
      database.Command.Parameters.Clear();
      database.Command.ExecuteNonQuery();
      // Get Entry Id
      database.Command.CommandText = GetIdentity;
      entry = System.Convert.ToUInt32(
				database.Command.ExecuteScalar()
			);

      // Make Journal Inserts
      database.Command.CommandText = InsertJournalEntries;
      database.Command.Parameters.Add(new Parameter() { Name = "@clientCulture", Value = 1033 });
      database.Command.Parameters.Add(new Parameter() { Name = "@entry", Value = entry });
      database.Command.Parameters.Add(new Parameter() { Name = "@book", Value = book });
      database.Command.Parameters.Add(new Parameter() { Name = "@amount", Value = amount });
      database.Command.ExecuteNonQuery();

      return entry;
		}

		// Parameter @book
		private const string GetBookIdSQL = @"
SELECT BookName.book
FROM BookName
JOIN Sentence ON Sentence.id = BookName.name
 AND Sentence.value = @book
 AND Sentence.culture = 1033
LIMIT 1;
";

		private const string GetEntryIdSQL = @"
INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL);
";

		private const string GetIdentity = @"
SELECT LAST_INSERT_ROWID();
";

		// Parameters @clientCulture, @entry, @amount, @book
		private const string InsertJournalEntries = "WITH " +
      AccountsCTE + "," +
			BooksCTE +
			@"
 INSERT INTO JournalEntry (journal, book, entry,  account, credit, amount)
 SELECT journal,
  book,
  @entry AS entry,
  increase AS account,
  NOT increaseCredit AS credit,
  (@amount * increaseCreditIncrease) * split AS amount
 FROM Books
 WHERE Books.book = @book
  AND @amount * increaseCreditIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  @entry AS entry,
  increase AS account,
  increaseCredit AS credit,
  (@amount * increaseDebitIncrease) * split AS amount
 FROM Books
 WHERE Books.book = @book
  AND @amount * increaseDebitIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  @entry AS entry,
  decrease AS account,
  NOT decreaseCredit AS credit,
  (@amount * decreaseCreditDecrease) * split AS amount
 FROM Books
 WHERE Books.book = @book
  AND @amount * decreaseCreditDecrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  @entry AS entry,
  decrease AS account,
  decreaseCredit AS credit,
  (@amount * decreaseDebitDecrease) * split AS amount
 FROM Books
 WHERE Books.book = @book
  AND @amount * decreaseDebitDecrease IS NOT NULL
 ;
";
	}
}
