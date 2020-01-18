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
INSERT INTO JournalName (journal, name) VALUES (1, 112); -- Sales
INSERT INTO JournalName (journal, name) VALUES (2, 116); -- Sales Credits
INSERT INTO JournalName (journal, name) VALUES (3, 117); -- Purchases
INSERT INTO JournalName (journal, name) VALUES (4, 118); -- Purchases Debit
INSERT INTO JournalName (journal, name) VALUES (5, 119); -- Receipts
INSERT INTO JournalName (journal, name) VALUES (6, 120); -- Payments
INSERT INTO JournalName (journal, name) VALUES (7, 121); -- Petty Cash
