using System;
namespace Business.Core
{
	public partial class Function
	{

    // VIEWS as CTEs to preserve indexes
    // Parameter @clientCulture
    public const string AccountsCTE = @"
Accounts AS (
SELECT AccountName.account,
 Sentence.value AS name,
 AccountName.type,
 TypeName.value AS typeName,
 IndividualAccount.individual,
 COALESCE(People.fullname, Entities.name) AS individualName,
 IndividualAccount.type AS individualAccountType,
 IndividualAccountType.value AS individualAccountTypeName,
 AccountName.credit,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitIncrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitDecrease,

 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditIncrease,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditDecrease
FROM AccountName
JOIN Sentence ON Sentence.id = AccountName.name
 AND Sentence.culture = @clientCulture
JOIN Word AS TypeName ON TypeName.id = AccountName.type
 AND TypeName.culture = @clientCulture
LEFT JOIN IndividualAccount ON IndividualAccount.account = AccountName.account
 AND IndividualAccount.stop IS NULL
LEFT JOIN People ON People.individual = IndividualAccount.individual
LEFT JOIN Entities ON Entities.individual = IndividualAccount.individual
LEFT JOIN Word AS IndividualAccountType ON IndividualAccountType.id = IndividualAccount.type
 AND IndividualAccountType.culture = @clientCulture
)
";

    // Parameter @clientCulture
    public const string BooksCTE = @"
Books AS (
SELECT BookName.book,
 Sentence.value AS name,
 BookName.journal,
 Journals.name AS journalName,
 COALESCE(BookAccount.split, 1) AS split,
 BookAccount.increase,
 Increase.name AS increaseName,
 Increase.type AS increaseType,
 Increase.credit AS increaseCredit,
 Increase.debitIncrease  AS increaseDebitIncrease,
 Increase.debitDecrease  AS increaseDebitDecrease,
 Increase.creditIncrease AS increaseCreditIncrease,
 Increase.creditDecrease  AS increaseCreditDecrease,
 BookAccount.decrease,
 Decrease.name AS decreaseName,
 Decrease.type AS decreaseType,
 Decrease.credit AS decreaseCredit,
 Decrease.debitIncrease  AS decreaseDebitIncrease,
 Decrease.debitDecrease  AS decreaseDebitDecrease,
 Decrease.creditIncrease AS decreaseCreditIncrease,
 Decrease.creditDecrease AS decreaseCreditDecrease
FROM BookName
JOIN Sentence ON Sentence.id = BookName.name
 AND Sentence.culture = @clientCulture
JOIN Journals ON Journals.journal = BookName.journal
JOIN BookAccount ON BookAccount.book = BookName.book
LEFT JOIN Accounts AS Increase ON Increase.account = BookAccount.increase
LEFT JOIN Accounts AS Decrease  ON Decrease.account  = BookAccount.decrease
)
";

  }
}
