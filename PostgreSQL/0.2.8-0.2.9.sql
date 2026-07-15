-- Update from 0.2.8 to 0.2.9
\set ON_ERROR_STOP on

DO $$
BEGIN
 -- Check 2: correct schema exists
 IF NOT EXISTS (
  SELECT true
  FROM pg_namespace
  WHERE nspname = 'business'
 ) THEN
  RAISE EXCEPTION 'Schema "Business" does not exist in this database';
 END IF;

 SET search_path TO business, public;

 -- Check to be sure current schema version is 0.2.7
 IF NOT EXISTS (
  SELECT true
  FROM schemaversion
  JOIN word AS schema ON schema.id = schemaversion.schema
  JOIN version on version.id = schemaversion.version
  JOIN word AS major ON major.id = version.major
  JOIN word as minor ON minor.id = version.minor
  JOIN word as patch on patch.id = version.patch
  WHERE schema.value = 'Business'
   AND major.value = '0'
   AND minor.value = '2'
   AND patch.value = '8'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.8';
 END IF;

END $$;

SET search_path TO business, public;

-- Book Charity payments
INSERT INTO Sentence (id,culture,value,length) VALUES (215,1033,'Checking',8);
INSERT INTO Sentence (id,culture,value,length) VALUES (216,1033,'Savings',7);
INSERT INTO Sentence (id,culture,value,length) VALUES (217,1033,'Food Bank',9);
INSERT INTO Sentence (id,culture,value,length) VALUES (218,1033,'Humane Society',24);
INSERT INTO Sentence (id,culture,value,length) VALUES (219,1033,'Fisher House Foundation',23);
INSERT INTO Sentence (id,culture,value,length) VALUES (220,1033,'Donations',9);
INSERT INTO Sentence (id,culture,value,length) VALUES (221,1033,'Charity',7);
INSERT INTO Sentence (id,culture,value,length) VALUES (222,1033,'AP Donation',11);
INSERT INTO Sentence (id,culture,value,length) VALUES (223,1033,'Donation Payment',16);

INSERT INTO AccountName (account, name, type, credit) VALUES (110, 215, 70000, false); -- Checking
INSERT INTO AccountName (account, name, type, credit) VALUES (111, 216, 70000, false); -- Savings
INSERT INTO AccountName (account, name, type, credit) VALUES (210, 217, 70001, true);  -- Food Bank
INSERT INTO AccountName (account, name, type, credit) VALUES (211, 218, 70001, true);  -- Humane Society
INSERT INTO AccountName (account, name, type, credit) VALUES (212, 219, 70001, true);  -- Fisher House Foundation
INSERT INTO AccountName (account, name, type, credit) VALUES (700, 220, 70004, false); -- Donations

-- Charity Books
INSERT INTO JournalName (journal, name) VALUES (10, 221); -- Charity
INSERT INTO LedgerJournal (ledger, journal) VALUES (1, 10);
INSERT INTO BookName (book, name, journal) VALUES (22, 222, 10); -- AP Donation
INSERT INTO BookName (book, name, journal) VALUES (23, 223, 10); -- Donation Payment
-- Book Donations Payable
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (22, 700, NULL, NULL); -- Donation Expense: 100%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (22, NULL, 210, .50);  -- Food Bank: 50%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (22, NULL, 211, .10);  -- Humane Society: 10%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (22, NULL, 212, .40);  -- Fisher House: 40%
-- Book Donations Paid
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (23, NULL, 110, NULL); -- Checking 100%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (23, 210, NULL, .50);  -- Donation Food Bank: 50%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (23, 211, NULL, .10);  -- Donation Humane Society: 10%
INSERT INTO BookAccount (book, increase, decrease, split) VALUES (23, 212, NULL, .40);  -- Donation Fisher House: 40%

