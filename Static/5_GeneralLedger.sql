-- General Ledger

-- Ledger (T) Accounts
INSERT INTO AccountName (account, name, type, credit) VALUES (1, 70, 70000, false); -- Asset
INSERT INTO AccountName (account, name, type, credit) VALUES (2, 71, 70001, true);  -- Liability
INSERT INTO AccountName (account, name, type, credit) VALUES (3, 72, 70003, true);  -- Income
INSERT INTO AccountName (account, name, type, credit) VALUES (4, 73, 70004, false); -- Expense
INSERT INTO AccountName (account, name, type, credit) VALUES (5, 74, 70002, true);  -- Equity
INSERT INTO AccountName (account, name, type, credit) VALUES (6, 78, 70000, false); -- Equipment
INSERT INTO AccountName (account, name, type, credit) VALUES (7, 89, 70001, true);  -- Payable
--
INSERT INTO LedgerName (ledger, name) VALUES (1, 84);
INSERT INTO LedgerAccount (ledger, account, sequence) VALUES
 (1, 1, 1),
 (1, 2, 2),
 (1, 3, 3),
 (1, 4, 4),
 (1, 5, 5),
 (1, 7, 6)
;

-- Journals
INSERT INTO JournalName (journal, name) VALUES (1, 84);  -- General
INSERT INTO JournalName (journal, name) VALUES (2, 112); -- Sales
INSERT INTO JournalName (journal, name) VALUES (3, 117); -- Purchases
INSERT INTO JournalName (journal, name) VALUES (4, 119); -- Receipts
INSERT INTO JournalName (journal, name) VALUES (5, 122); -- Liabilities
INSERT INTO JournalName (journal, name) VALUES (6, 120); -- Payments
INSERT INTO JournalName (journal, name) VALUES (7, 121); -- Petty Cash

-- Ledger Journals
INSERT INTO LedgerJournal (ledger, journal) VALUES
 (1, 1),
 (1, 2),
 (1, 3),
 (1, 4),
 (1, 5),
 (1, 6),
 (1, 7)
;

-- Books
INSERT INTO BookName (book, name, journal) VALUES (1,  107, 6); -- Rent, Payments
INSERT INTO BookName (book, name, journal) VALUES (2,  126, 2); -- Sale, Sales
INSERT INTO BookName (book, name, journal) VALUES (3,  116, 2); -- Sales Credit, Sales
INSERT INTO BookName (book, name, journal) VALUES (4,  78,  3); -- Equipment, Purchases
INSERT INTO BookName (book, name, journal) VALUES (5,  127, 3); -- Equipment Return, Purchases
INSERT INTO BookName (book, name, journal) VALUES (6,  77 , 5); -- Loan, Liabilities
INSERT INTO BookName (book, name, journal) VALUES (7,  124, 5); -- Loan Payment, Liabilities
INSERT INTO BookName (book, name, journal) VALUES (8,  81 , 6); -- Salary, Payments
INSERT INTO BookName (book, name, journal) VALUES (9,  100, 6); -- Supplies, Payments
INSERT INTO BookName (book, name, journal) VALUES (10, 125, 6); -- Supply Returns, Payments
INSERT INTO BookName (book, name, journal) VALUES (11, 121, 7); -- Petty Cash, Petty Cash
INSERT INTO BookName (book, name, journal) VALUES (12, 128, 7); -- Petty Cash Return, Petty Cash
INSERT INTO BookName (book, name, journal) VALUES (13, 212, 2); -- AR Sale, Sales
INSERT INTO BookName (book, name, journal) VALUES (14, 213, 2); -- AR Sale Credit, Sales
INSERT INTO BookName (book, name, journal) VALUES (15, 214, 2); -- AR Sale Payment, Sales

-- Simple Book Accounts
-- Must define balanced transactions to be inserted into journals
INSERT INTO AccountName (account, name, type, credit) VALUES (100, 76,  70000, false); -- Cash
INSERT INTO AccountName (account, name, type, credit) VALUES (101, 107, 70004, false); -- Rent
INSERT INTO AccountName (account, name, type, credit) VALUES (102, 112, 70003, true);  -- Sales
INSERT INTO AccountName (account, name, type, credit) VALUES (103, 78,  70000, false); -- Equipment
INSERT INTO AccountName (account, name, type, credit) VALUES (104, 77,  70001, true);  -- Loan
INSERT INTO AccountName (account, name, type, credit) VALUES (105, 81,  70004, false); -- Salary
INSERT INTO AccountName (account, name, type, credit) VALUES (106, 100, 70004, false); -- Supply
INSERT INTO AccountName (account, name, type, credit) VALUES (107, 121, 70000, false); -- Petty Cash
INSERT INTO AccountName (account, name, type, credit) VALUES (108, 90,  70000, false); -- Receivable
--
INSERT INTO BookAccount (book, increase, decrease) VALUES (1, 101, 100); -- Rent Payment: Rent, Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (2, 100, 102); -- Sale: Cash, Sales
INSERT INTO BookAccount (book, increase, decrease) VALUES (3, 102, 100); -- Sale Credit: Sales, Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (4, 103, 100); -- Equipment Purchase: Equipment, Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (5, 100, 103); -- Equipment Return: Cash, Equipment
INSERT INTO BookAccount (book, increase, decrease) VALUES (6, 100, 104); -- Loan: Cash, Loan
INSERT INTO BookAccount (book, increase, decrease) VALUES (7, 104, 100); -- Loan Payment: Loan, Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (8, 105, 100); -- Salary: Salary, Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (9, 106, 100); -- Supplies: Supply, Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (10, 100, 106);-- Supply Return: Cash, Supply
INSERT INTO BookAccount (book, increase, decrease) VALUES (11, 106, 107);-- Petty Cash: Supply, Petty Cash
INSERT INTO BookAccount (book, increase, decrease) VALUES (12, 107, 106);-- Petty Cash Return: Petty Cash, Supply
INSERT INTO BookAccount (book, increase, decrease) VALUES (13, 108, 102);-- AR Sale: Receivable, Sales
INSERT INTO BookAccount (book, increase, decrease) VALUES (14, 102, 108);-- AR Sale Credit: Sales, Receivable
INSERT INTO BookAccount (book, increase, decrease) VALUES (15, 100, 108);-- AR Payment: Cash, Receivable

-- More Complex Book Accounts
-- Split amount across acounts
-- Book Commission Sales for Jane and John Doe
INSERT INTO JournalName (journal, name) VALUES (20, 200); -- Commission Sales
INSERT INTO LedgerJournal (ledger, journal) VALUES (1, 20);
INSERT INTO BookName (book, name, journal) VALUES (20, 210, 7); -- Sale Jane Doe
INSERT INTO BookName (book, name, journal) VALUES (21, 211, 7); -- Sale John Doe
INSERT INTO AccountName (account, name, type, credit) VALUES (200, 201,  70001, true);   -- Commissions Payable
-- Book Jane Commission Sales
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (20, 100,  NULL, NULL); -- Commision Sale: Cash 100%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (20, NULL, 102,  .80);  -- Comission Sale: Sales 80%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (20, NULL, 200,  .20);  -- Comission Sale: Comission 20%
-- Book Jone Commission Sales
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (21, 100,  NULL, NULL); -- Commision Sale: Cash 100%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (21, NULL, 102,  .85);  -- Comission Sale: Sales 85%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (21, NULL, 200,  .15);  -- Comission Sale: Comission 15%
