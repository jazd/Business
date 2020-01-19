-- General Ledger

-- Ledger (T) Accounts
INSERT INTO AccountName (account, name, type, credit) VALUES (1, 70, 70000, false); -- Asset
INSERT INTO AccountName (account, name, type, credit) VALUES (2, 71, 70001, true);  -- Liability
INSERT INTO AccountName (account, name, type, credit) VALUES (3, 72, 70003, true);  -- Income
INSERT INTO AccountName (account, name, type, credit) VALUES (4, 73, 70004, false); -- Expense
INSERT INTO AccountName (account, name, type, credit) VALUES (5, 74, 70002, true);  -- Equity
INSERT INTO AccountName (account, name, type, credit) VALUES (6, 78, 70000, false); -- Equipment
INSERT INTO AccountName (account, name, type, credit) VALUES (7, 89, 70001, true);  -- Payable
INSERT INTO AccountName (account, name, type, credit) VALUES (8, 90, 70000, false); -- Receivable
--
INSERT INTO LedgerName (ledger, name) VALUES (1, 84);
INSERT INTO LedgerAccount (ledger, account) VALUES
 (1, 1),
 (1, 2),
 (1, 3),
 (1, 4),
 (1, 5),
 (1, 7),
 (1, 8)
;

-- Journals
INSERT INTO JournalName (journal, name) VALUES (1, 84);  -- General
INSERT INTO JournalName (journal, name) VALUES (2, 112); -- Sales
INSERT INTO JournalName (journal, name) VALUES (3, 117); -- Purchases
INSERT INTO JournalName (journal, name) VALUES (4, 119); -- Receipts
INSERT INTO JournalName (journal, name) VALUES (5, 122); -- Liabilities
INSERT INTO JournalName (journal, name) VALUES (6, 120); -- Payments
INSERT INTO JournalName (journal, name) VALUES (7, 121); -- Petty Cash

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
--
INSERT INTO BookAccount (book, credit, debit) VALUES (1, 100, 101); -- Rent Payment: Cash, Rent
INSERT INTO BookAccount (book, credit, debit) VALUES (2, 102, 100); -- Sale: Sales, Cash
INSERT INTO BookAccount (book, credit, debit) VALUES (3, 100, 102); -- Sale Credit: Cash, Sales
INSERT INTO BookAccount (book, credit, debit) VALUES (4, 100, 103); -- Equipment Purchase: Cash, Equipment
INSERT INTO BookAccount (book, credit, debit) VALUES (5, 102, 100); -- Equipment Return: Equipment, Cash
INSERT INTO BookAccount (book, credit, debit) VALUES (6, 104, 100); -- Loan: Loan, Cash
INSERT INTO BookAccount (book, credit, debit) VALUES (7, 100, 104); -- Loan Payment: Cash, Loan
INSERT INTO BookAccount (book, credit, debit) VALUES (8, 100, 105); -- Salary: Cash, Salary
INSERT INTO BookAccount (book, credit, debit) VALUES (9, 100, 106); -- Supplies: Cash, Supply
INSERT INTO BookAccount (book, credit, debit) VALUES (10, 106, 100);-- Supply Return: Supply, Cash
INSERT INTO BookAccount (book, credit, debit) VALUES (11, 107, 106);-- Petty Cash: Petty Cash, Supply
