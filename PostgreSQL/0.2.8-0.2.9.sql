-- =============================================================================
-- Business schema upgrade: 0.2.8 -> 0.2.9 (PostgreSQL)
-- =============================================================================
--
-- Changes since git tag 0.2.8. Script body upgrades an existing 0.2.8 database.
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.8 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.8-0.2.9.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.8 database)
-- ---------------------------------------------------------------------------
--
-- 1) Charity / AP donation accounting (also in Static/ for fresh installs)
--    * Sentences 215-220, 222-223 (en-US): Checking, Savings, Food Bank,
--      Humane Society, Fisher House Foundation, Donations, AP Donation,
--      Donation Payment. Journal label "Charity" uses existing Sentence 95.
--    * Accounts 110, 111, 210-212, 700; Journal 10; books 22-23 with splits
--      (expense 100%; payables 50/10/40; payment from Checking).
--
-- 2) Money columns: float -> numeric(19,4) (schema.xml + ALTER here)
--    * AccountName.amount; JournalAccount.amount/split; BookAccount.amount/
--      split; IndividualAssemblyCost.cost; IndividualAssemblyCustomerPrice
--      .price; Schedule fromAmount/toAmount/rateCost/price/cost;
--      AssemblyIndividualJobPrice.price.
--    * JournalEntry.amount was already numeric(19,4) at 0.2.8.
--    * Still float (by design): Cargo.count, CargoState.count,
--      Schedule.fromCount/toCount/rate; Attribute.float; Variance.value.
--    * All business views dropped, then recreated after type changes (~47).
--
-- 3) Word/Sentence concurrency and indexes (post.sql + procedures)
--    * word_value_null UNIQUE on Word(UPPER(value)) WHERE culture IS NULL.
--    * sentence_value remains non-unique for cultured rows (shared
--      translations, e.g. Alquiler for Rent and Rental); sentence_value_null
--      for identity phrases.
--    * GetWord / GetIdentifier / GetSentence / GetIdentityPhrase: re-check
--      under advisory lock; ON CONFLICT where unique indexes apply; every
--      advisory lock path releases on EXCEPTION WHEN OTHERS.
--    * Full CREATE OR REPLACE of the PostgreSQL procedure set (Book/Post
--      take numeric amounts; JournalEntryResult recreated with CASCADE).
--
-- 4) EST device bring-up write procedures (procedures.d/65-est.sql)
--    * PutAssemblyPublicKey(assembly, pem) — soft-stop prior active key,
--      then insert PEM.
--    * PutCertificateSigningRequest(pem, individual) and overload with
--      session — insert CSR, return id.
--    * PutAssemblyCertificateSigningRequest(assembly, csr) — soft-stop
--      prior active link, then insert.
--    * PutCertificate(caPolicy, type, individual, csr, start, days, o, ou,
--      cn, email, serial, pem) — type is Word value (e.g. 'Client');
--      returns certificate id.
--    * Included in full procedure refresh and CREATE OR REPLACE near end
--      of this script for databases already on the prior 0.2.9 body.
--
-- 5) Schema version
--    * SetSchemaVersion('Business', '0', '2', '9') — stops 0.2.8, activates
--      0.2.9.
--
-- ---------------------------------------------------------------------------
-- Other release package changes (since tag 0.2.8)
-- ---------------------------------------------------------------------------
--
-- 6) NuoDB removed (deprecated)
--    * Removed NuoDB/ tree, schema.nuodb target, Core.NuoDB, profile hooks,
--      and Makefile NuoDB paths.
--
-- 7) Build / packaging
--    * Makefile: oracle and sybase schema targets; NuoDB targets removed.
--
-- 8) SQLite post.sql sequence starts
--    * PeriodName, LedgerName, JournalName, BookName, AccountName now set
--      sqlite_sequence high-water marks
--
-- 9) Diagrams (genDiagrams.sh + regenerated PNGs)
--    * Addresses/Phones include IndividualAddress/Phone and AddressAttribute.
--    * Session includes IndividualApplicationCreated; Assemblies includes
--      Application.
--    * New diagrams/i18n.png and diagrams/software.png.
--
-- 10) Bash/sqlite client helpers
--    * Fixes: PutAssemblyPart shebang; GetPartbySerial SQL-escapes serial.
--    * New: GetEmail, GetIndividualEmail, PutAssemblyPublicKey,
--      PutCertificateSigningRequest, PutAssemblyCertificateSigningRequest,
--      PutCertificate
--
-- TESTING
--   * Validate on a copy of production 0.2.8 data before cutover.
--   * DBFit tests pass
--
-- =============================================================================
\set ON_ERROR_STOP on

DO $$
BEGIN
 -- Check: Business schema exists
 IF NOT EXISTS (
  SELECT true
  FROM pg_namespace
  WHERE nspname = 'business'
 ) THEN
  RAISE EXCEPTION 'Schema "Business" does not exist in this database';
 END IF;

 SET search_path TO business, public;

 -- Require current schema version 0.2.8
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

-- Book Charity payments (reuse Sentence id 95 for journal name Charity)
INSERT INTO Sentence (id,culture,value,length) VALUES (215,1033,'Checking',8);
INSERT INTO Sentence (id,culture,value,length) VALUES (216,1033,'Savings',7);
INSERT INTO Sentence (id,culture,value,length) VALUES (217,1033,'Food Bank',9);
INSERT INTO Sentence (id,culture,value,length) VALUES (218,1033,'Humane Society',24);
INSERT INTO Sentence (id,culture,value,length) VALUES (219,1033,'Fisher House Foundation',23);
INSERT INTO Sentence (id,culture,value,length) VALUES (220,1033,'Donations',9);
INSERT INTO Sentence (id,culture,value,length) VALUES (222,1033,'AP Donation',11);
INSERT INTO Sentence (id,culture,value,length) VALUES (223,1033,'Donation Payment',16);

INSERT INTO AccountName (account, name, type, credit) VALUES (110, 215, 70000, false); -- Checking
INSERT INTO AccountName (account, name, type, credit) VALUES (111, 216, 70000, false); -- Savings
INSERT INTO AccountName (account, name, type, credit) VALUES (210, 217, 70001, true);  -- Food Bank
INSERT INTO AccountName (account, name, type, credit) VALUES (211, 218, 70001, true);  -- Humane Society
INSERT INTO AccountName (account, name, type, credit) VALUES (212, 219, 70001, true);  -- Fisher House Foundation
INSERT INTO AccountName (account, name, type, credit) VALUES (700, 220, 70004, false); -- Donations

-- Charity Books
INSERT INTO JournalName (journal, name) VALUES (10, 95); -- Charity (existing Sentence 95)
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


-- Drop all views so money column types can be altered (views depend on some of them)
DO $$
DECLARE
 r RECORD;
BEGIN
 FOR r IN
  SELECT quote_ident(schemaname) AS s, quote_ident(viewname) AS v
  FROM pg_views
  WHERE schemaname = 'business'
 LOOP
  EXECUTE 'DROP VIEW IF EXISTS ' || r.s || '.' || r.v || ' CASCADE';
 END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 0.2.9: Money / amounts as numeric(19,4) (was float)
-- count / fromCount / toCount / rate stay float
-- ---------------------------------------------------------------------------
ALTER TABLE AccountName ALTER COLUMN amount TYPE numeric(19,4) USING amount::numeric(19,4);
ALTER TABLE JournalAccount ALTER COLUMN amount TYPE numeric(19,4) USING amount::numeric(19,4);
ALTER TABLE JournalAccount ALTER COLUMN split TYPE numeric(19,4) USING split::numeric(19,4);
ALTER TABLE BookAccount ALTER COLUMN amount TYPE numeric(19,4) USING amount::numeric(19,4);
ALTER TABLE BookAccount ALTER COLUMN split TYPE numeric(19,4) USING split::numeric(19,4);
ALTER TABLE IndividualAssemblyCost ALTER COLUMN cost TYPE numeric(19,4) USING cost::numeric(19,4);
ALTER TABLE IndividualAssemblyCustomerPrice ALTER COLUMN price TYPE numeric(19,4) USING price::numeric(19,4);
ALTER TABLE Schedule ALTER COLUMN fromAmount TYPE numeric(19,4) USING fromAmount::numeric(19,4);
ALTER TABLE Schedule ALTER COLUMN toAmount TYPE numeric(19,4) USING toAmount::numeric(19,4);
ALTER TABLE Schedule ALTER COLUMN rateCost TYPE numeric(19,4) USING rateCost::numeric(19,4);
ALTER TABLE Schedule ALTER COLUMN price TYPE numeric(19,4) USING price::numeric(19,4);
ALTER TABLE Schedule ALTER COLUMN cost TYPE numeric(19,4) USING cost::numeric(19,4);
ALTER TABLE AssemblyIndividualJobPrice ALTER COLUMN price TYPE numeric(19,4) USING price::numeric(19,4);

-- ---------------------------------------------------------------------------
-- 0.2.9: GetWord / Get* concurrency + advisory-lock leak safety
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS word_value_null ON Word(UPPER(value)) WHERE culture IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sentence_value_null ON Sentence(UPPER(value)) WHERE culture IS NULL;

-- Full procedure refresh from assembled PostgreSQL/procedures.sql (procedures.d sources)
SET search_path TO business, public;

-- Return the Id of a culture based word
-- It is inserted if it does not already exist
-- Concurrent safe: re-check under lock + ON CONFLICT on word_value; lock always released

-- I18N — Word / Sentence / Identifier (diagram: i18n)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
 word_id integer;
 lock_key bigint;
BEGIN
 IF word_value IS NOT NULL THEN
  -- Check if exists early
  SELECT id INTO word_id
  FROM Word
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Word.value) = UPPER(word_value)
   AND Word.culture = Culture.code
  LIMIT 1
  ;
  IF word_id IS NULL THEN
   lock_key := hashtext(word_value);
   -- Serialize concurrent inserts for the same text; always release the lock
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    SELECT id INTO word_id
    FROM Word
    JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
    WHERE UPPER(Word.value) = UPPER(word_value)
     AND Word.culture = Culture.code
    LIMIT 1;
    IF word_id IS NULL THEN
     INSERT INTO Word (value, culture)
     SELECT word_value, Culture.code
     FROM Culture
     WHERE UPPER(Culture.name) = UPPER(culture_name)
     ON CONFLICT (culture, (UPPER(value))) DO NOTHING;
     SELECT id INTO word_id
     FROM Word
     JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
     WHERE UPPER(Word.value) = UPPER(word_value)
      AND Word.culture = Culture.code
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN word_id;
END;
$$ LANGUAGE plpgsql;

-- Default to en-US
-- TODO: set a system wide default culture
CREATE OR REPLACE FUNCTION GetWord (
 word_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT GetWord(word_value, 'en-US') AS id
 );
END;
$$ LANGUAGE plpgsql;

-- Identifiers are normally by convention en-US based names used in programming and protocols
-- Return the Id of an identifier
-- It is inserted if it does not already exist
-- Concurrent safe: re-check under lock + ON CONFLICT on word_value_null
CREATE OR REPLACE FUNCTION GetIdentifier (
 ident_value varchar
) RETURNS integer AS $$
DECLARE
 ident_id integer;
 lock_key bigint;
BEGIN
 IF ident_value IS NOT NULL THEN
  -- Check if exists early
  SELECT id INTO ident_id
  FROM Word
  WHERE UPPER(Word.value) = UPPER(ident_value)
   AND Word.culture IS NULL
  LIMIT 1;
  IF ident_id IS NULL THEN
   lock_key := hashtext(ident_value);
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    SELECT id INTO ident_id
    FROM Word
    WHERE UPPER(Word.value) = UPPER(ident_value)
     AND Word.culture IS NULL
    LIMIT 1;
    IF ident_id IS NULL THEN
     INSERT INTO Word (value, culture)
     VALUES (ident_value, NULL)
     ON CONFLICT ((UPPER(value))) WHERE culture IS NULL DO NOTHING;
     SELECT id INTO ident_id
     FROM Word
     WHERE UPPER(Word.value) = UPPER(ident_value)
      AND Word.culture IS NULL
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN ident_id;
END;
$$ LANGUAGE plpgsql;

-- Concurrent safe: re-check under advisory lock then insert-if-missing.
-- Note: cultured Sentence values are NOT globally unique per culture (translations
-- of different English phrases may share text). Do not use ON CONFLICT on value.
CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
 sentence_id integer;
 lock_key bigint;
BEGIN
 IF sentence_value IS NOT NULL THEN
  SELECT id INTO sentence_id
  FROM Sentence
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Sentence.value) = UPPER(sentence_value)
   AND Sentence.culture = Culture.code
  LIMIT 1;
  IF sentence_id IS NULL THEN
   lock_key := hashtext(sentence_value);
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    -- Re-check after lock (another session may have inserted)
    SELECT id INTO sentence_id
    FROM Sentence
    JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
    WHERE UPPER(Sentence.value) = UPPER(sentence_value)
     AND Sentence.culture = Culture.code
    LIMIT 1;
    IF sentence_id IS NULL THEN
     INSERT INTO Sentence (value, culture, length) (
      SELECT sentence_value, Culture.code, LENGTH(sentence_value)
      FROM Culture
      LEFT JOIN Sentence AS exists ON UPPER(exists.value) = UPPER(sentence_value)
       AND exists.culture = Culture.code
      WHERE UPPER(Culture.name) = UPPER(culture_name)
       AND exists.id IS NULL
      LIMIT 1
     );
     SELECT id INTO sentence_id
     FROM Sentence
     JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
     WHERE UPPER(Sentence.value) = UPPER(sentence_value)
      AND Sentence.culture = Culture.code
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN sentence_id;
END;
$$ LANGUAGE plpgsql;

-- Default to en-US
CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT GetSentence(sentence_value, 'en-US') AS id
 );
END;
$$ LANGUAGE plpgsql;


-- Concurrent safe: re-check under lock + ON CONFLICT on sentence_value_null
CREATE OR REPLACE FUNCTION GetIdentityPhrase (
 phrase_value varchar
) RETURNS integer AS $$
DECLARE
 ident_id integer;
 lock_key bigint;
BEGIN
 IF phrase_value IS NOT NULL THEN
  SELECT id INTO ident_id
  FROM Sentence
  WHERE UPPER(Sentence.value) = UPPER(phrase_value)
   AND Sentence.culture IS NULL
  LIMIT 1;
  IF ident_id IS NULL THEN
   lock_key := hashtext(phrase_value);
   PERFORM pg_advisory_lock(lock_key);
   BEGIN
    SELECT id INTO ident_id
    FROM Sentence
    WHERE UPPER(Sentence.value) = UPPER(phrase_value)
     AND Sentence.culture IS NULL
    LIMIT 1;
    IF ident_id IS NULL THEN
     INSERT INTO Sentence (value, culture)
     VALUES (phrase_value, NULL)
     ON CONFLICT ((UPPER(value))) WHERE culture IS NULL DO NOTHING;
     SELECT id INTO ident_id
     FROM Sentence
     WHERE UPPER(Sentence.value) = UPPER(phrase_value)
      AND Sentence.culture IS NULL
     LIMIT 1;
    END IF;
    PERFORM pg_advisory_unlock(lock_key);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lock_key);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN ident_id;
END;
$$ LANGUAGE plpgsql;


-- Geo / Addresses — Location Postal Address (diagram: addresses)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetLocation (
 lat float,
 long float,
 accuracy_code integer
) RETURNS integer AS $$
DECLARE
 inLatitude NUMERIC(10,7);
 inLongitude NUMERIC(11,7);
 lockID bigint;
 location_id integer;
BEGIN
 inLatitude := lat;
 inLongitude := long;

 IF lat IS NOT NULL AND long IS NOT NULL THEN
  SELECT id INTO location_id
  FROM Location
  WHERE parent IS NULL
   AND marquee IS NULL
   AND longitude = inLongitude
   AND latitude = inLatitude
   AND ((accuracy = accuracy_code) OR (accuracy IS NULL AND accuracy_code IS NULL))
   AND level = 1 -- Default level
   AND altitudeabovesealevel IS NULL
   AND area IS NULL
  LIMIT 1;
  IF location_id IS NULL THEN
   -- Convert latitude numeric(10,7) to a 64 bit integer for lock
   lockID := (inLatitude * 10000000)::bigint;
   -- Be sure to process any single latitude one at a time without the need of a transaction or locking the Location table
   PERFORM pg_advisory_lock(lockID);
   BEGIN
   INSERT INTO Location (latitude, longitude, accuracy) (
    SELECT inLatitude, inLongitude, accuracy_code
    FROM Dual
    LEFT JOIN Location AS exists ON exists.latitude = inLatitude
     AND exists.longitude = inLongitude
     AND ((exists.accuracy = accuracy_code) OR (exists.accuracy IS NULL AND accuracy_code IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(lockID);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lockID);
     RAISE;
   END;
   SELECT id INTO location_id
   FROM Location
   WHERE parent IS NULL
    AND marquee IS NULL
    AND longitude = inLongitude
    AND latitude = inLatitude
    AND ((accuracy = accuracy_code) OR (accuracy IS NULL AND accuracy_code IS NULL))
    AND level = 1 -- Default level
    AND altitudeabovesealevel IS NULL
    AND area IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN location_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPostal (
 countrycode varchar,
 zipcode varchar,
 city varchar,
 statecode varchar,
 state varchar,
 county varchar,
 lat float,
 long float,
 accuracy integer
) RETURNS integer AS $$
DECLARE
 countrycode_id integer;
 city_id integer;
 statecode_id integer;
 state_id integer;
 county_id integer;
 location_id integer;
 postal_id integer;
BEGIN
 countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(countrycode));
 city_id := (SELECT GetWord(city));
 statecode_id := (SELECT GetWord(statecode));
 state_id := (SELECT GetWord(state));
 county_id := GetWord(county);
 location_id := (SELECT GetLocation(lat,long,accuracy));
 -- Be sure to process any single zipcode one at a time without the need of a transaction or locking the Postal table
 SELECT id INTO postal_id
 FROM Postal
 -- Unique on country and code
 WHERE country = countrycode_id
  AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
  AND UPPER(Postal.code) = UPPER(zipcode)
 LIMIT 1;
 IF postal_id IS NULL THEN
  PERFORM pg_advisory_lock(hashtext(UPPER(zipcode)));
  BEGIN
  INSERT INTO Postal (country, code, state, stateabbreviation, county, city, location) (
   SELECT countrycode_id, zipcode, state_id, statecode_id, county_id, city_id, location_id
   FROM Dual
   LEFT JOIN Postal AS exists ON exists.country = countrycode_id
    AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
    AND UPPER(exists.code) = UPPER(zipcode)
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(hashtext(UPPER(zipcode)));
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(hashtext(UPPER(zipcode)));
    RAISE;
  END;
  SELECT id INTO postal_id
  FROM Postal
  -- Unique on country and code
  WHERE country = countrycode_id
   AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
   AND UPPER(Postal.code) = UPPER(zipcode)
  LIMIT 1;
 END IF;
 RETURN postal_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPostal (
 countrycode varchar,
 zipcode varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 -- Do not insert unless we have all the non-nullable fields
 -- Unique on country and code
 RETURN (
  SELECT Postal.id
  FROM Postal
  JOIN Country ON UPPER(Country.code) = UPPER(countrycode)
  LEFT JOIN Location ON Location.id = Postal.location
  WHERE Postal.country = Country.id
   AND UPPER(Postal.code) = UPPER(zipcode)
  ORDER BY Location.accuracy ASC NULLS LAST, Postal.id DESC
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- Default to USA
CREATE OR REPLACE FUNCTION GetPostal (
 zipcode varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 -- Do not insert unless we have all the non-nullable fields
 -- Unique on country and code
 RETURN (
  -- TODO Currently most accurate Postal Code from all countries
  SELECT Postal.id
  FROM Postal
  LEFT JOIN Location ON Location.id = Postal.location
  WHERE UPPER(Postal.code) = UPPER(zipcode)
  ORDER BY Location.accuracy ASC NULLS LAST, Postal.id DESC
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- Default to USA
CREATE OR REPLACE FUNCTION GetAddress (
 street varchar,
 zipcode varchar,
 inPostalplus varchar(4),
 lat float,
 long float,
 inAccuracy integer
) RETURNS integer AS $$
DECLARE
 location_id integer;
 zipcode_id integer;
 address_id integer;
BEGIN
  location_id := (SELECT GetLocation(lat,long,inAccuracy));
  zipcode_id := (SELECT GetPostal(zipcode));

  IF zipcode_id IS NOT NULL THEN
   IF location_id IS NOT NULL THEN
    -- Attempt update location of existing address
    UPDATE Address
    SET location = location_id
    WHERE location IS NULL
     AND postal = zipcode_id
     AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
     AND UPPER(line1) = UPPER(street)
     AND line2 IS NULL
     AND line3 IS NULL
     AND line4 IS NULL
    ;
   END IF;
   SELECT id INTO address_id
   FROM Address
   WHERE postal = zipcode_id
    AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
    AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
    AND UPPER(line1) = UPPER(street)
    AND line2 IS NULL
    AND line3 IS NULL
    AND line4 IS NULL
   LIMIT 1;
   IF address_id IS NULL THEN
    -- Be sure to process any single zipcode id one at a time without the need of a transaction or locking the Address table
    PERFORM pg_advisory_lock(zipcode_id);
    BEGIN
    INSERT INTO Address (line1, postal, postalplus, location) (
     SELECT street, zipcode_id, inPostalplus, location_id
     FROM Dual
     LEFT JOIN Address AS exists ON exists.postal = zipcode_id
      AND ((exists.postalplus = inPostalplus) OR (exists.postalplus IS NULL AND inPostalplus IS NULL))
      AND ((exists.location = location_id) OR (exists.location IS NULL AND location_id IS NULL))
      AND UPPER(exists.line1) = UPPER(street)
      AND exists.line2 IS NULL
      AND exists.line3 IS NULL
      AND exists.line4 IS NULL
     WHERE exists.id IS NULL
     LIMIT 1
    );
    PERFORM pg_advisory_unlock(zipcode_id);
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(zipcode_id);
      RAISE;
    END;
    SELECT id INTO address_id
    FROM Address
    WHERE postal = zipcode_id
     AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
     AND ((location = location_id) OR (location IS NULL AND location_id IS NULL))
     AND UPPER(line1) = UPPER(street)
     AND line2 IS NULL
     AND line3 IS NULL
     AND line4 IS NULL
    LIMIT 1;
   END IF;
  END IF;
  RETURN address_id;
END;
$$ LANGUAGE plpgsql;

-- Default to USA
CREATE OR REPLACE FUNCTION GetAddress (
 street varchar,
 zipcode varchar,
 inPostalplus varchar(4)
) RETURNS integer AS $$
DECLARE
 zipcode_id integer;
 address_id integer;
BEGIN
  -- Do not call GetPostal with nulls so that this will return addresses with location information
  zipcode_id := (SELECT GetPostal(zipcode));

  IF zipcode_id IS NOT NULL THEN
   SELECT id INTO address_id
   FROM Address
   WHERE postal = zipcode_id
    AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
    AND UPPER(line1) = UPPER(street)
    AND line2 IS NULL
    AND line3 IS NULL
    AND line4 IS NULL
   ORDER BY location
   LIMIT 1; -- pickup a location based address first
   IF address_id IS NULL THEN
    -- Be sure to process any single zipcode id one at a time without the need of a transaction or locking the Address table
    PERFORM pg_advisory_lock(zipcode_id);
    BEGIN
    INSERT INTO Address (line1, postal, postalplus) (
     SELECT street, zipcode_id, inPostalplus
     FROM Dual
     LEFT JOIN Address AS exists ON exists.postal = zipcode_id
      AND ((exists.postalplus = inPostalplus) OR (exists.postalplus IS NULL AND inPostalplus IS NULL))
      AND UPPER(exists.line1) = UPPER(street)
      AND exists.line2 IS NULL
      AND exists.line3 IS NULL
      AND exists.line4 IS NULL
     WHERE exists.id IS NULL
     LIMIT 1
    );
    PERFORM pg_advisory_unlock(zipcode_id);
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(zipcode_id);
      RAISE;
    END;
    SELECT id INTO address_id
    FROM Address
    WHERE postal = zipcode_id
     AND ((postalplus = inPostalplus) OR (postalplus IS NULL AND inPostalplus IS NULL))
     AND UPPER(line1) = UPPER(street)
     AND line2 IS NULL
     AND line3 IS NULL
     AND line4 IS NULL
    ORDER BY location
    LIMIT 1; -- pickup a location based address first
   END IF;
  END IF;
 RETURN address_id;
END;
$$ LANGUAGE plpgsql;


-- Individual / Entity / Name (diagram: individual)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetGiven (
 inGiven varchar
) RETURNS integer AS $$
DECLARE
 given_id integer;
BEGIN
 IF inGiven IS NOT NULL THEN
  SELECT id INTO given_id
  FROM Given
  WHERE Given.value = inGiven
  LIMIT 1;
  IF given_id IS NULL THEN
   -- Be sure to process any single given one at a time without the need of a transaction or locking Given table
   PERFORM pg_advisory_lock(hashtext(inGiven));
   BEGIN
   INSERT INTO Given (value) (
    SELECT inGiven
    FROM DUAL
    LEFT JOIN Given AS exists ON exists.value = inGiven
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(hashtext(inGiven));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inGiven));
     RAISE;
   END;
   SELECT id INTO given_id
   FROM Given
   WHERE Given.value = inGiven
   LIMIT 1;
  END IF;
 END IF;
 RETURN given_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFamily (
 inFamily varchar
) RETURNS integer AS $$
DECLARE
 family_id integer;
BEGIN
 IF inFamily IS NOT NULL THEN
  SELECT id INTO family_id
  FROM Family
  WHERE Family.value = inFamily
  LIMIT 1;
  IF family_id IS NULL THEN
   -- Be sure to process any single family one at a time without the need of a transaction or locking Family table
   PERFORM pg_advisory_lock(hashtext(inFamily));
   BEGIN
   INSERT INTO Family (value) (
    SELECT inFamily
    FROM DUAL
    LEFT JOIN Family AS exists ON exists.value = inFamily
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(hashtext(inFamily));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inFamily));
     RAISE;
   END;
   SELECT id INTO family_id
   FROM Family
   WHERE Family.value = inFamily
   LIMIT 1;
  END IF;
 END IF;
 RETURN family_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetName (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar
) RETURNS integer AS $$
DECLARE
 first_id integer;
 middle_id integer;
 last_id integer;
 name_id integer;
BEGIN
 IF inFirst IS NOT NULL OR inMiddle IS NOT NULL OR inLast IS NOT NULL THEN
  -- get given and family values
  first_id := (SELECT GetGiven(inFirst));
  middle_id := (SELECT GetGiven(inMiddle));
  last_id := (SELECT GetFamily(inLast));
  SELECT id INTO name_id
  FROM Name
  WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
    AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
    AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
  LIMIT 1;
  IF name_id IS NULL THEN
   -- Be sure to process any single first one at a time without the need of a transaction or locking Name table
   PERFORM pg_advisory_lock(first_id);
   BEGIN
   INSERT INTO Name (given, middle, family) (
    SELECT first_id, middle_id, last_id
    FROM DUAL
    LEFT JOIN Name AS exists ON
         ((exists.given = first_id) OR (exists.given IS NULL AND first_id IS NULL))
     AND ((exists.middle = middle_id) OR (exists.middle IS NULL AND middle_id IS NULL))
     AND ((exists.family = last_id) OR (exists.family IS NULL AND last_id IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(first_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(first_id);
     RAISE;
   END;
   SELECT id INTO name_id
   FROM Name
   WHERE ((Name.given = first_id) OR (Name.given IS NULL AND first_id IS NULL))
     AND ((Name.middle = middle_id) OR (Name.middle IS NULL AND middle_id IS NULL))
     AND ((Name.family = last_id) OR (Name.family IS NULL AND last_id IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN name_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetIndividualPerson (
 inHonorific varchar, -- prefix
 inFirst varchar,
 inMiddle varchar,
 inLast varchar,
 inSuffix varchar,
 inPost varchar,
 inBirth date, -- Can't be null
 inBirthLocation integer,
 inGoesBy varchar,
 inDeath date
) RETURNS bigint AS $$
DECLARE
 name_id integer;
 prefix_id integer;
 suffix_id integer;
 post_id integer;
 goesBy_id integer;
 lockID bigint;
 individual_id bigint;
BEGIN
 -- Check for possible duplicate before inserting Name
 individual_id := (
   SELECT exists.id
   FROM DUAL -- If first, last and birthday match any existing, consider it a duplicate and refuse to insert new Individual with this function
   LEFT JOIN Given ON Given.value = inFirst
   LEFT JOIN Family ON Family.value = inLast
   LEFT JOIN Name ON ((Name.given = Given.id) OR (Name.given IS NULL AND Given.id IS NULL))
    AND ((Name.family = Family.id) OR (Name.family IS NULL AND Family.id IS NULL))
   LEFT JOIN Individual AS exists ON exists.name IN (name_id, Name.id)
    AND ((CAST(exists.birth AS DATE) = inBirth) OR (inBirth IS NULL))
   LIMIT 1
 );

 IF individual_id IS NULL THEN
  name_id := (SELECT GetName(inFirst,inMiddle,inLast));
  prefix_id := (SELECT GetWord(inHonorific));
  suffix_id := (SELECT GetWord(inSuffix));
  post_id := (SELECT GetWord(inPost));
  goesBy_id := (SELECT GetGiven(inGoesBy));

  IF name_id IS NOT NULL AND inBirth IS NOT NULL THEN
   -- Be sure to process any single birthdate one at a time without the need of a transaction or locking the Individual table
   lockID := extract(epoch FROM inBirth)::bigint;
   PERFORM pg_advisory_lock(lockID);
   BEGIN
   INSERT INTO Individual(name, prefix, suffix, post, goesBy, birth, location, death) VALUES (name_id, prefix_id, suffix_id, post_id, goesBy_id, inBirth, inBirthLocation, inDeath);
   PERFORM pg_advisory_unlock(lockID);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lockID);
     RAISE;
   END;
  END IF;

  individual_id := (
   SELECT id
   FROM Individual
   WHERE Individual.name = name_id
   AND (CAST(Individual.birth AS DATE) = inBirth) -- Null birth inserts are not allowd in this function
   AND ((Individual.goesBy = goesBy_id) OR (goesBy_id IS NULL))
   AND ((CAST(Individual.death AS DATE) = inDeath) OR (Individual.death IS NULL AND inDeath IS NULL))
   LIMIT 1
  );
 END IF;

 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetIndividualPerson (
 inFirst varchar,
 inMiddle varchar,
 inLast varchar,
 inBirth date, -- Can't be null
 inGoesBy varchar,
 inDeath date
) RETURNS bigint AS $$
BEGIN
 RETURN GetIndividualPerson(NULL, inFirst, inMiddle, inLast, NULL, NULL, inBirth, NULL, inGoesBy, inDeath);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetEntityName (
 inName varchar
) RETURNS integer AS $$
DECLARE
 entity_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  SELECT id INTO entity_id
  FROM Entity
  WHERE UPPER(Entity.name) = UPPER(inName)
  LIMIT 1;
  IF entity_id IS NULL THEN
   -- Be sure to process any single name one at a time without the need of a transaction or locking the Entity table
   PERFORM pg_advisory_lock(hashtext(inName));
   BEGIN
   INSERT INTO Entity (name)
   SELECT inName
   FROM DUAL
   LEFT JOIN Entity AS exists ON UPPER(exists.name) = UPPER(inName)
   WHERE exists.id IS NULL
   LIMIT 1;
   PERFORM pg_advisory_unlock(hashtext(inName));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inName));
     RAISE;
   END;
   SELECT id INTO entity_id
   FROM Entity
   WHERE UPPER(Entity.name) = UPPER(inName)
   LIMIT 1;
  END IF;
 END IF;
 RETURN entity_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar,
 inFormed date,
 inGoesBy varchar,
 inDissolved date
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 goesBy_id integer;
 individual_id bigint;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  goesBy_id := (SELECT GetGiven(inGoesBy));
  SELECT id INTO individual_id
  FROM Individual
  WHERE Individual.entity = entity_name_id
  LIMIT 1;
  IF individual_id IS NULL THEN
   -- Be sure to process any single entity name id one at a time without the need of a transaction or locking Individual table
   PERFORM pg_advisory_lock(entity_name_id);
   BEGIN
   INSERT INTO Individual (entity, goesBy, birth, death)
   SELECT entity_name_id, goesBy_id, inFormed, inDissolved
   FROM DUAL
   LEFT JOIN Individual AS exists ON exists.entity = entity_name_id
   WHERE exists.id IS NULL
   LIMIT 1;
   PERFORM pg_advisory_unlock(entity_name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(entity_name_id);
     RAISE;
   END;
   SELECT id INTO individual_id
   FROM Individual
   WHERE Individual.entity = entity_name_id
   LIMIT 1;
  END IF;
 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 individual_id bigint;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  -- Be sure to process any single entity name id one at a time without the need of a transaction or locking Individual table
  SELECT id INTO individual_id
  FROM Individual
  WHERE entity = entity_name_id
  LIMIT 1;
  IF individual_id IS NULL THEN
   PERFORM pg_advisory_lock(entity_name_id);
   BEGIN
   INSERT INTO Individual (entity) VALUES (entity_name_id) RETURNING id INTO individual_id;
   PERFORM pg_advisory_unlock(entity_name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(entity_name_id);
     RAISE;
   END;
  END IF;
 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CreateIndividual (
) RETURNS bigint AS $$
DECLARE
BEGIN
 INSERT INTO Individual (birth) VALUES(NULL);
 RETURN (SELECT currval(pg_get_serial_sequence('individual','id')));
END;
$$ LANGUAGE plpgsql;


-- Contacts — Email Phone Path (diagrams: individual_email, phones, individual_path)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetEmail (
 inUserName varchar,
 inPlus varchar,
 inHost varchar
) RETURNS integer AS $$
DECLARE
 email_id integer;
BEGIN
 IF inUserName IS NOT NULL AND inHost IS NOT NULL THEN
  SELECT id INTO email_id
  FROM Email
  WHERE UPPER(username) = UPPER(inUserName)
   AND UPPER(host) = UPPER(inHost)
   AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
  LIMIT 1;
  IF email_id IS NULL THEN
   -- Be sure to process any single username one at a time without the need of a transaction or locking Email table
   PERFORM pg_advisory_lock(hashtext(inUserName));
   BEGIN
   INSERT INTO Email (username, plus, host) (
    SELECT inUserName, inPlus, inHost
    FROM DUAL
    LEFT JOIN Email AS exists ON UPPER(exists.username) = UPPER(inUserName)
     AND UPPER(exists.host) = UPPER(inHost)
     AND ((UPPER(exists.plus) = UPPER(inPlus)) OR (exists.plus IS NULL AND inPlus IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(hashtext(inUserName));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inUserName));
     RAISE;
   END;
   SELECT id INTO email_id
   FROM Email
   WHERE UPPER(username) = UPPER(inUserName)
    AND UPPER(host) = UPPER(inHost)
    AND ((UPPER(plus) = UPPER(inPlus)) OR (plus IS NULL AND inPlus IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN email_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetEmail (
 inEmail varchar
) RETURNS integer AS $$
DECLARE
 userHostSplit varchar[];  -- Remember these start at 1 not 0
 userPlusSplit varchar[];
BEGIN
 IF inEmail IS NOT NULL THEN
  userHostSplit := (SELECT (regexp_split_to_array(inEmail,'@'))[1:2]);
  userPlusSplit := (SELECT (regexp_split_to_array(userHostSplit[1],'\+'))[1:2]);
 END IF;
 RETURN (
  SELECT GetEmail(userPlusSplit[1], userPlusSplit[2], userHostSplit[2]) AS id
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id bigint,
 inEmail_id integer,
 inType varchar
) RETURNS bigint AS $$
DECLARE
 type_id integer;
BEGIN
 IF inIndividual_id IS NOT NULL
  AND inEmail_id IS NOT NULL THEN
  type_id := (SELECT GetWord(inType));
  -- Be sure to process any single individual email one at a time without the need of a transaction or locking IndividualEmail table
  PERFORM pg_advisory_lock(inIndividual_id);
  BEGIN
  INSERT INTO IndividualEmail (individual, email, type) (
   SELECT inIndividual_id, inEmail_id, type_id
   FROM DUAL
   LEFT JOIN IndividualEmail AS exists ON exists.individual = inIndividual_id
    AND exists.email = inEmail_id
    AND ((exists.type = type_id) OR (exists.type IS NULL AND type_id IS NULL))
    AND exists.stop IS NULL
   WHERE exists.individual IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inIndividual_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inIndividual_id);
    RAISE;
  END;
  -- Be sure to stop any previous emails of this type associated with this individual
  UPDATE IndividualEmail
  SET stop = NOW()
  WHERE individual = inIndividual_id
   AND email != inEmail_id
   AND Stop IS NULL
   AND ((type = type_id) OR (type IS NULL AND type_id IS NULL))
  ;
 END IF;
 RETURN inIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualEmail (
 inIndividual_id bigint,
 inEmail_id integer
) RETURNS bigint AS $$
DECLARE
BEGIN
 RETURN SetIndividualEmail(inIndividual_id, inEmail_id, NULL);
END;
$$ LANGUAGE plpgsql;

-- Get Individual associated with an email
CREATE OR REPLACE FUNCTION GetIndividualEmail (
  inEmail varchar
) RETURNS bigint AS $$
DECLARE
 email_id integer;
 individual_id bigint;
BEGIN
 -- Get email id
 email_id := (SELECT GetEmail(inEmail));

 IF email_id IS NOT NULL THEN
  -- Is email already associated with an individual?
  individual_id := (
   SELECT individual
   FROM IndividualEmail
   WHERE email = email_id
    AND stop IS NULL
   LIMIT 1
  );

  IF individual_id IS NULL THEN
   -- Email not associated with any individual, so create new individual
   individual_id = (SELECT CreateIndividual());
  END IF;

  -- Associate email with individual
  PERFORM SetIndividualEmail(individual_id, email_id);

 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPath (
 inProtocol varchar,
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar
) RETURNS integer AS $$
DECLARE
 is_secure integer := 0;
 lockText varchar;
 lockID bigint;
 path_id integer;
BEGIN
 -- host and path can not both be null
 IF inValue IS NOT NULL OR inHost IS NOT NULL THEN
  -- Default to false or 0
  IF inSecure IS NOT NULL AND inSecure != 0 THEN
    is_secure :=1;
  END IF;
  lockText := COALESCE(inHost, '') || COALESCE(inValue, '');
  lockID := hashtext(lockText);
  SELECT id INTO path_id
  FROM Path
  WHERE protocol = inProtocol
   AND secure = is_secure
   AND ((UPPER(host) = UPPER(inHost)) OR (host IS NULL and inHost IS NULL))
   AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
   AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
  LIMIT 1;
  IF path_id IS NULL THEN
   -- Be sure to process any single path one at a time without the need of a transaction or locking Path table
   PERFORM pg_advisory_lock(lockID);
   BEGIN
   INSERT INTO Path (protocol, secure, host, value, get) (
    SELECT inProtocol, is_secure, inHost, inValue, inGet
    FROM Dual
    LEFT JOIN Path AS exists ON exists.protocol = inProtocol
     AND exists.secure = is_secure
     AND ((UPPER(exists.host) = UPPER(inHost)) OR (exists.host IS NULL AND inHost IS NULL))
     AND ((exists.value = inValue) OR (exists.value IS NULL OR inValue IS NULL))
     AND ((exists.get = inGet) OR (exists.get IS NULL AND inGet IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(lockID);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(lockID);
     RAISE;
   END;
   SELECT id INTO path_id
   FROM Path
   WHERE protocol = inProtocol
    AND secure = is_secure
    AND ((UPPER(host) = UPPER(inHost)) OR (host IS NULL and inHost IS NULL))
    AND ((value = inValue) OR (value IS NULL AND inValue IS NULL))
    AND ((get = inGet) OR (get IS NULL AND inGet IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN path_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetURL (
 inSecure integer,
 inHost varchar,
 inValue varchar,
 inGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetPath('http', inSecure, inHost, inValue, inGet));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetFile (
 inHost varchar,
 inPathValue varchar,
 inFileGet varchar
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetPath('file', 0, inHost, inPathValue, inFileGet));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPhone (
 inCountryCode varchar,
 inAreaCode varchar,
 inNumber varchar
) RETURNS integer AS $$
DECLARE
 countrycode_id integer;
 phone_id integer;
BEGIN
 IF inNumber IS NOT NULL THEN
  countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(inCountryCode));
  IF countrycode_id IS NOT NULL THEN
   SELECT id INTO phone_id
   FROM Phone
   WHERE country = countrycode_id
    AND area = inAreaCode
    AND number = inNumber
   LIMIT 1;
   IF phone_id IS NULL THEN
    -- Be sure to process any single phone number one at a time without the need of a transaction or locking Phone table
    PERFORM pg_advisory_lock(hashtext(inNumber));
    BEGIN
    INSERT INTO Phone (country, area, number) (
     SELECT countrycode_id, inAreaCode, inNumber
     FROM Dual
     LEFT JOIN Phone AS exists ON exists.country = countrycode_id
      AND exists.area = inAreaCode
      AND exists.number = inNumber
     WHERE exists.id IS NULL
     LIMIT 1
    );
    PERFORM pg_advisory_unlock(hashtext(inNumber));
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(hashtext(inNumber));
      RAISE;
    END;
    SELECT id INTO phone_id
    FROM Phone
    WHERE country = countrycode_id
     AND area = inAreaCode
     AND number = inNumber
    LIMIT 1;
   END IF;
  END IF;
 END IF;
 RETURN phone_id;
END;
$$ LANGUAGE plpgsql;


-- For examples only.  Don't use in a production environment

-- Lists (diagram: lists)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetListIndividualName (
 inListName varchar,
 inSetName varchar
) RETURNS integer AS $$
DECLARE
 listName_id integer;
 setName_id integer;
 listIndividual_id integer;
BEGIN
 IF inListName IS NOT NULL THEN
  -- Get names
  listName_id := (SELECT GetWord(inListName));
  setName_id := (SELECT GetWord(inSetName));
  SELECT listIndividual INTO listIndividual_id
  FROM ListIndividualName
  WHERE name = listName_id
   AND ((listSet = setName_id) OR (listSet IS NULL AND setName_id IS NULL))
   AND optinStyle = 1
  LIMIT 1;
  IF listIndividual_id IS NULL THEN
   -- Insert list name if it does not exist
   -- Be sure to process any single list name id one at a time without the need of a transaction or locking ListIndividualName table
   PERFORM pg_advisory_lock(listName_id);
   BEGIN
   INSERT INTO ListIndividualName (name, listSet, optinStyle)
   SELECT listName_id, setName_id, 1
   FROM DUAL
   LEFT JOIN ListIndividualName AS exists ON exists.name = listName_id
    AND ((exists.listSet = setName_id) OR (exists.listSet IS NULL AND setName_id IS NULL))
    AND exists.optinStyle = 1
   WHERE exists.listIndividual IS NULL
   LIMIT 1
   ;
   PERFORM pg_advisory_unlock(listName_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(listName_id);
     RAISE;
   END;
   SELECT listIndividual INTO listIndividual_id
   FROM ListIndividualName
   WHERE name = listName_id
    AND ((listSet = setName_id) OR (listSet IS NULL AND setName_id IS NULL))
    AND optinStyle = 1
   LIMIT 1;
  END IF;
 END IF;
 RETURN listIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual bigint,
 inSend varchar
) RETURNS integer AS $$
DECLARE
 listIndividual_id integer;
 sendField_id integer;
BEGIN
 IF inIndividual IS NOT NULL AND inListName IS NOT NULL THEN
  sendField_id := (SELECT GetIdentifier(LOWER(inSend)));
  listIndividual_id := (SELECT GetListIndividualName(inListName, inSetName));

  -- Insert individual into list
  -- Be sure to process any single list individual id one at a time without the need of a transaction or locking ListIndividual table
  PERFORM pg_advisory_lock(listIndividual_id);
  BEGIN
  INSERT INTO ListIndividual (id, individual, type)
  SELECT listIndividual_id AS id, inIndividual AS individual, sendField_id AS type
  FROM DUAL
  LEFT JOIN ListIndividual AS exists ON exists.id = listIndividual_id
   AND exists.individual = inIndividual
   AND exists.unlist IS NULL
  WHERE exists.id IS NULL
  LIMIT 1
  ;
  PERFORM pg_advisory_unlock(listIndividual_id);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(listIndividual_id);
    RAISE;
  END;
 END IF;

 RETURN listIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual bigint
) RETURNS integer AS $$
BEGIN
 -- Use default send to
 RETURN (SELECT ListSubscribe(inListName, inSetName, inIndividual, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribe (
 inListName varchar,
 inIndividual bigint
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListSubscribe(inListName, NULL, inIndividual));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName varchar,
 inSetName varchar,
 inIndividual bigint
) RETURNS integer AS $$
DECLARE
 listIndividual_id integer;
BEGIN
 IF inIndividual IS NOT NULL AND inListName IS NOT NULL THEN
  listIndividual_id := (SELECT GetListIndividualName(inListName, inSetName));

  IF listIndividual_id IS NOT NULL THEN
   UPDATE ListIndividual SET unlist = NOW()
   WHERE ListIndividual.id = listIndividual_id
    AND ListIndividual.individual = inIndividual
    AND ListIndividual.unlist IS NULL
   ;
  END IF;

 END IF;

 RETURN listIndividual_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListUnSubscribe (
 inListName varchar,
 inIndividual bigint
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT ListUnSubscribe(inListName, NULL, inIndividual));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribeEmail (
 inListName varchar,
 inSetName varchar,
 inEmail varchar
) RETURNS integer AS $$
DECLARE
 individual_id bigint;
BEGIN
 individual_id := (GetIndividualEmail(inEmail));

 -- Subscribe individual to the list
 RETURN (SELECT ListSubscribe(inListName, inSetName, individual_id));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ListSubscribeEmail (
 inListName varchar,
 inEmail varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (SELECT ListSubscribeEmail(inListName, NULL, inEmail));
END;
$$ LANGUAGE plpgsql;


-- Software / Parts / Assemblies (diagrams: software, assemblies)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION GetVersion (
 inMajor varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE
 major_id integer;
 minor_id integer;
 patch_id integer;
 version_id integer;
BEGIN
 major_id := (SELECT GetWord(inMajor));
 IF major_id IS NOT NULL THEN
  minor_id := (SELECT GetWord(inMinor));
  patch_id := (SELECT GetWord(inPatch));
  SELECT id INTO version_id
  FROM Version
  WHERE major = major_id
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
   AND name IS NULL
  LIMIT 1;
  IF version_id IS NULL THEN
   -- Be sure to process any single version one at a time without the need of a transaction or locking Version table
   PERFORM pg_advisory_lock(major_id);
   BEGIN
   INSERT INTO Version (major, minor, patch) (
    SELECT major_id, minor_id, patch_id
    FROM Dual
    LEFT JOIN Version AS exists ON exists.major = major_id
     AND ((exists.minor = minor_id) OR (exists.minor IS NULL AND minor_id IS NULL))
     AND ((exists.patch = patch_id) OR (exists.patch IS NULL AND patch_id IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(major_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(major_id);
     RAISE;
   END;
   SELECT id INTO version_id
   FROM Version
   WHERE major = major_id
    AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
    AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
    AND name IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN version_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetVersionName (
 inName varchar,
 inMajor varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 major_id integer;
 minor_id integer;
 patch_id integer;
 version_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetWord(inName));
  major_id := (SELECT GetWord(inMajor));
  minor_id := (SELECT GetWord(inMinor));
  patch_id := (SELECT GetWord(inPatch));
  SELECT id INTO version_id
  FROM Version
  WHERE name = name_id
   AND ((major = major_id) OR (major IS NULL AND major_id IS NULL))
   AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
   AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
  LIMIT 1;
  IF version_id IS NULL THEN
   -- Be sure to process any single version name one at a time without the need of a transaction or locking Version table
   PERFORM pg_advisory_lock(name_id);
   BEGIN
   INSERT INTO Version (name, major, minor, patch) (
    SELECT name_id, major_id, minor_id, patch_id
    FROM Dual
    LEFT JOIN Version AS exists ON exists.name = name_id
     AND ((exists.major = major_id) OR (exists.major IS NULL AND major_id IS NULL))
     AND ((exists.minor = minor_id) OR (exists.minor IS NULL AND minor_id IS NULL))
     AND ((exists.patch = patch_id) OR (exists.patch IS NULL AND patch_id IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(name_id);
     RAISE;
   END;
   SELECT id INTO version_id
   FROM Version
   WHERE name = name_id
    AND ((major = major_id) OR (major IS NULL AND major_id IS NULL))
    AND ((minor = minor_id) OR (minor IS NULL AND minor_id IS NULL))
    AND ((patch = patch_id) OR (patch IS NULL AND patch_id IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN version_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetVersionName (
 inName varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (SELECT GetVersionName(inName, NULL, NULL, NULL));
END;
$$ LANGUAGE plpgsql;

-- GetRelease(version integer, build char)
CREATE OR REPLACE FUNCTION GetRelease (
 inVersion integer,
 inBuild varchar
) RETURNS integer AS $$
DECLARE
 build_id integer;
 release_id integer;
BEGIN
 IF inVersion IS NOT NULL THEN
  build_id := (SELECT GetWord(inBuild));
  SELECT id INTO release_id
  FROM Release
  WHERE version = inVersion
   AND ((build = build_id) OR (build IS NULL AND build_id IS NULL))
  LIMIT 1;
  IF release_id IS NULL THEN
   -- Be sure to process any single version build one at a time without the need of a transaction or locking Release table
   PERFORM pg_advisory_lock(inVersion);
   BEGIN
   INSERT INTO Release (build, version) (
    SELECT build_id AS build, inVersion AS version
    FROM Dual
    LEFT JOIN Release AS exists ON exists.version = inVersion
     AND ((exists.build = build_id) OR (exists.build IS NULL AND build_id IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inVersion);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inVersion);
     RAISE;
   END;
   SELECT id INTO release_id
   FROM Release
   WHERE version = inVersion
    AND ((build = build_id) OR (build IS NULL AND build_id IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN release_id;
END;
$$ LANGUAGE plpgsql;

-- GetRelease(version integer)
CREATE OR REPLACE FUNCTION GetRelease (
 inVersion integer
) RETURNS integer AS $$
BEGIN
 RETURN (SELECT GetRelease(inVersion, NULL));
END;
$$ LANGUAGE plpgsql;

-- GetApplication(name char)
CREATE OR REPLACE FUNCTION GetApplication(
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_ident integer;
 application_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_ident := (SELECT GetWord(inName));
  SELECT id INTO application_id
  FROM Application
  WHERE name = name_ident
  LIMIT 1;
  IF application_id IS NULL THEN
   -- Be sure to process any single application one at a time without the need of a transaction or locking Application table
   PERFORM pg_advisory_lock(name_ident);
   BEGIN
   INSERT INTO Application (name) (
    SELECT name_ident AS name
    FROM Dual
    LEFT JOIN Application AS exists ON exists.name = name_ident
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(name_ident);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(name_ident);
     RAISE;
   END;
   SELECT id INTO application_id
   FROM Application
   WHERE name = name_ident
   LIMIT 1;
  END IF;
 END IF;
 RETURN application_id;
END;
$$ LANGUAGE plpgsql;

-- GetApplicationRelease(application integer, release integer)
CREATE OR REPLACE FUNCTION GetApplicationRelease (
 inApplication integer,
 inRelease integer
) RETURNS integer AS $$
DECLARE
 applicationRelease_id integer;
BEGIN
 IF inApplication IS NOT NULL THEN
  SELECT id INTO applicationRelease_id
  FROM ApplicationRelease
  WHERE application = inApplication
   AND ((release = inRelease) OR (release IS NULL AND inRelease IS NULL))
  LIMIT 1;
  IF applicationRelease_id IS NULL THEN
   -- Be sure to process any single application release one at a time without the need of a transaction or locking ApplicationRelease table
   PERFORM pg_advisory_lock(inApplication);
   BEGIN
   INSERT INTO ApplicationRelease (application, release) (
    SELECT inApplication AS application, inRelease AS release
    FROM Dual
    LEFT JOIN ApplicationRelease AS exists ON exists.application = inApplication
     AND ((exists.release = inRelease) OR (exists.release IS NULL AND inRelease IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inApplication);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inApplication);
     RAISE;
   END;
   SELECT id INTO applicationRelease_id
   FROM ApplicationRelease
   WHERE application = inApplication
    AND ((release = inRelease) OR (release IS NULL AND inRelease IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN applicationRelease_id;
END;
$$ LANGUAGE plpgsql;

-- GetPart(name varchar)
-- Getting a Part without a version returns a root part with a null parent, version and serial
CREATE OR REPLACE FUNCTION GetPart (
 inName varchar
) RETURNS integer AS $$
DECLARE
 name_id integer;
 part_id integer;
BEGIN
 IF inName IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  SELECT id INTO part_id
  FROM Part
  WHERE name = name_id
   AND parent IS NULL
   AND version IS NULL
   AND serial IS NULL
  LIMIT 1;
  IF part_id IS NULL THEN
   -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
   PERFORM pg_advisory_lock(name_id);
   BEGIN
   INSERT INTO Part (name) (
    SELECT name_id
    FROM Dual
    LEFT JOIN Part AS exists ON exists.name = name_id
     AND exists.parent IS NULL
     AND exists.version IS NULL
     AND exists.serial IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(name_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(name_id);
     RAISE;
   END;
   SELECT id INTO part_id
   FROM Part
   WHERE name = name_id
    AND parent IS NULL
    AND version IS NULL
    AND serial IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

-- GetPartWithParent(name varchar, parentId integer) Specify an exact parent for Part without version
CREATE OR REPLACE FUNCTION GetPartWithParent (
 inNameId integer,
 inParentId integer
) RETURNS integer AS $$
DECLARE
 part_id integer;
BEGIN
 IF inNameId IS NOT NULL AND inParentId IS NOT NULL THEN
  -- Insert if it does not alread exists
  SELECT id INTO part_id
  FROM Part
  WHERE name = inNameId
   AND parent = inParentId
   AND version IS NULL
   AND serial IS NULL
  LIMIT 1;
  IF part_id IS NULL THEN
   -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
   PERFORM pg_advisory_lock(inNameId);
   BEGIN
   INSERT INTO Part (name, parent) (
    SELECT inNameId, inParentId
    FROM Dual
    LEFT JOIN Part AS exists ON exists.name = inNameId
     AND exists.parent = inParentId
     AND exists.version IS NULL
     AND exists.serial IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inNameId);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inNameId);
     RAISE;
   END;
   SELECT id INTO part_id
   FROM Part
   WHERE name = inNameId
    AND parent = inParentId
    AND version IS NULL
    AND serial IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPartWithParent (
 inName varchar,
 inParentId integer
) RETURNS integer AS $$
DECLARE name_id integer;
BEGIN
 name_id := (SELECT GetSentence(inName));
 RETURN (
  SELECT GetPartWithParent(name_id, inParentId)
 );
END;
$$ LANGUAGE plpgsql;

-- Child and Parent by name when building a non-versioned part hierarchy
CREATE OR REPLACE FUNCTION GetPartWithParent (
 inPartName varchar,
 inParentName varchar
) RETURNS integer AS $$
DECLARE
 part_name_id integer;
 parent_name_id integer;
 parent_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inParentName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  parent_name_id := (SELECT GetSentence(inParentName));

  -- Find the lowest non-versioned part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND version IS NULL
    AND serial IS NULL
   ORDER BY parent ASC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create a root part
   parent_id := (SELECT GetPart(inParentName));
  END IF;
  RETURN (
   SELECT GetPartWithParent(part_name_id, parent_id)
  );
 END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPartWithParent (
 inPartName varchar,
 inParentName varchar,
 inParentVersionName varchar
) RETURNS integer AS $$
DECLARE
 part_name_id integer;
 parent_name_id integer;
 parent_version_name_id integer;
 parent_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inParentName IS NOT NULL AND inParentVersionName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  parent_name_id := (SELECT GetSentence(inParentName));
  parent_version_name_id := GetVersionName(inParentVersionName);
  -- Find the lowest version name part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND version = parent_version_name_id
    AND serial IS NULL
   ORDER BY parent ASC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create parent
   parent_id := (SELECT GetPart(inParentName,inParentVersionName));
  END IF;
  RETURN (
   SELECT GetPartWithParent(part_name_id, parent_id)
  );
 END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPartWithParent (
 inPartName varchar,
 inPartVersionName varchar,
 inParentName varchar,
 inParentVersionName varchar
) RETURNS integer AS $$
DECLARE
 part_name_id integer;
 part_version_name_id integer;
 parent_name_id integer;
 parent_version_name_id integer;
 parent_id integer;
 part_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inPartVersionName IS NOT NULL AND inParentName IS NOT NULL AND inParentVersionName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  part_version_name_id := GetVersionName(inPartVersionName);
  parent_name_id := (SELECT GetSentence(inParentName));
  parent_version_name_id := GetVersionName(inParentVersionName);
  -- Find the lowest version name part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND version = parent_version_name_id
    AND serial IS NULL
   ORDER BY parent ASC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create parent
   parent_id := (SELECT GetPart(inParentName,inParentVersionName));
  END IF;
  SELECT id INTO part_id
  FROM Part
  WHERE parent = parent_id
   AND name = part_name_id
   AND version = part_version_name_id
   AND serial IS NULL
  LIMIT 1;
  IF part_id IS NULL THEN
   PERFORM pg_advisory_lock(parent_id);
   BEGIN
   INSERT INTO Part (parent, name, version) (
    SELECT parent_id, part_name_id, part_version_name_id
    FROM Dual
    LEFT JOIN Part AS exists ON exists.parent = parent_id
     AND exists.name = part_name_id
     AND exists.version = part_version_name_id
     AND serial IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(parent_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(parent_id);
     RAISE;
   END;
   SELECT id INTO part_id
   FROM Part
   WHERE parent = parent_id
   AND name = part_name_id
   AND version = part_version_name_id
   AND serial IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPartWithParentNearest (
 inPartName varchar,
 inPartVersionName varchar,
 inParentName varchar,
 inParentVersionName varchar
) RETURNS integer AS $$
DECLARE
 part_name_id integer;
 part_version_name_id integer;
 parent_name_id integer;
 parent_version_name_id integer;
 parent_id integer;
 part_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inPartVersionName IS NOT NULL AND inParentName IS NOT NULL AND inParentVersionName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  part_version_name_id := GetVersionName(inPartVersionName);
  parent_name_id := (SELECT GetSentence(inParentName));
  parent_version_name_id := GetVersionName(inParentVersionName);
  -- Find the highest version name part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND version = parent_version_name_id
    AND serial IS NULL
   ORDER BY parent DESC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create parent
   parent_id := (SELECT GetPart(inParentName,inParentVersionName));
  END IF;
  SELECT id INTO part_id
  FROM Part
  WHERE parent = parent_id
   AND name = part_name_id
   AND version = part_version_name_id
   AND serial IS NULL
  LIMIT 1;
  IF part_id IS NULL THEN
   PERFORM pg_advisory_lock(parent_id);
   BEGIN
   INSERT INTO Part (parent, name, version) (
    SELECT parent_id, part_name_id, part_version_name_id
    FROM Dual
    LEFT JOIN Part AS exists ON exists.parent = parent_id
     AND exists.name = part_name_id
     AND exists.version = part_version_name_id
     AND serial IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(parent_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(parent_id);
     RAISE;
   END;
   SELECT id INTO part_id
   FROM Part
   WHERE parent = parent_id
   AND name = part_name_id
   AND version = part_version_name_id
   AND serial IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

-- Does no Part INSERTs
CREATE OR REPLACE FUNCTION GetPartWithAncestor (
 inPartName varchar,
 inPartVersionName varchar,
 inAncestorName varchar,
 inAncestorVersionName varchar
) RETURNS integer AS $$
DECLARE
 part_name_id integer;
 part_version_name_id integer;
 ancestor_name_id integer;
 ancestor_version_name_id integer;
 ancestor_id integer;
 parent_id integer;
 part_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inPartVersionName IS NOT NULL AND inAncestorName IS NOT NULL AND inAncestorVersionName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  part_version_name_id := GetVersionName(inPartVersionName);
  ancestor_name_id := (SELECT GetSentence(inAncestorName));
  ancestor_version_name_id := GetVersionName(inAncestorVersionName);
  -- Find the highest version parent with provided ancestor
  ancestor_id = (
   SELECT id
   FROM Part
   WHERE name = ancestor_name_id
    AND version = ancestor_version_name_id
    AND serial IS NULL
   ORDER BY id DESC
   LIMIT 1
  );
  IF ancestor_id IS NOT NULL THEN
   parent_id = (
    SELECT id
    FROM Part
    WHERE parent = ancestor_id
     AND version IS NOT NULL
     AND serial IS NULL
    ORDER BY id DESC
    LIMIT 1
   );
   IF parent_id IS NOT NULL THEN
    SELECT id INTO part_id
    FROM Part
    WHERE parent = parent_id
     AND name = part_name_id
     AND version = part_version_name_id
     AND serial IS NULL
    LIMIT 1;
   END IF;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetPartWithParentVersion (
 inPartName varchar,
 inPartVersion_id integer,
 inParentName varchar,
 inParentVersion_id integer
) RETURNS integer AS $$
DECLARE
 part_name_id integer;
 parent_name_id integer;
 parent_id integer;
 part_id integer;
BEGIN
 IF inPartName IS NOT NULL AND inParentName IS NOT NULL THEN
  part_name_id := (SELECT GetSentence(inPartName));
  parent_name_id := (SELECT GetSentence(inParentName));
  -- Find the lowest version name part of parent name
  parent_id = (
   SELECT id
   FROM Part
   WHERE name = parent_name_id
    AND ((version = inParentVersion_id) OR (version IS NULL AND inParentVersion_id IS NULL))
    AND serial IS NULL
   ORDER BY parent ASC -- Non NULLs first
   LIMIT 1
  );
  IF parent_id IS NULL THEN
   -- Create parent
   parent_id := (SELECT GetPart(inParentName, inParentVersion_id));
  END IF;
  SELECT id INTO part_id
  FROM Part
  WHERE parent = parent_id
   AND name = part_name_id
   AND ((version = inPartVersion_id) OR (version IS NULL AND inPartVersion_id IS NULL))
   AND serial IS NULL
  LIMIT 1;
  IF part_id IS NULL THEN
   PERFORM pg_advisory_lock(parent_id);
   BEGIN
   INSERT INTO Part (parent, name, version) (
    SELECT parent_id, part_name_id, inPartVersion_id
    FROM Dual
    LEFT JOIN Part AS exists ON exists.parent = parent_id
     AND exists.name = part_name_id
     AND ((exists.version = inPartVersion_id) OR (exists.version IS NULL AND inPartVersion_id IS NULL))
     AND serial IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(parent_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(parent_id);
     RAISE;
   END;
   SELECT id INTO part_id
   FROM Part
   WHERE parent = parent_id
    AND name = part_name_id
    AND ((version = inPartVersion_id) OR (version IS NULL AND inPartVersion_id IS NULL))
    AND serial IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersion integer
) RETURNS integer AS $$
DECLARE
 name_id integer;
 sibling_id integer;
 parent_id integer;
 part_id integer;
BEGIN
 IF inName IS NOT NULL AND inVersion IS NOT NULL THEN
  name_id := (SELECT GetSentence(inName));
  -- Every non-root part must have a parent
  -- Does it have a direct sibling with a parent?
  sibling_id := (SELECT Part.parent
   FROM Part
   WHERE Part.name = name_id
    AND Part.version IS NOT NULL
    AND Part.serial IS NULL
   LIMIT 1
  );
  IF sibling_id IS NULL THEN
   -- No siblings, try same part without a version but has a parent
   parent_id := (SELECT Part.id
    FROM Part
    WHERE Part.name = name_id
     AND Part.parent IS NOT NULL
     AND Part.version IS NULL
     AND Part.serial IS NULL
     LIMIT 1
   );
   IF parent_id IS NULL THEN
    -- Try same part without version or parent (root part)
    -- If not found it will create it
    parent_id := (SELECT GetPart(inName));
   END IF;
  ELSE
   -- Use sibling parent
   parent_id := sibling_id;
  END IF;
  -- Insert this part if it is not a duplicate
  SELECT id INTO part_id
  FROM Part
  WHERE name = name_id
   AND parent = parent_id
   AND version = inVersion
   AND serial IS NULL
  LIMIT 1;
  IF part_id IS NULL THEN
   -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
   PERFORM pg_advisory_lock(parent_id);
   BEGIN
   INSERT INTO Part (parent, name, version) (
    SELECT parent_id, name_id, inVersion
    FROM Dual
    LEFT JOIN Part AS exists ON exists.parent = parent_id
     AND exists.name = name_id
     AND exists.version = inVersion
     AND exists.serial IS NULL
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(parent_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(parent_id);
     RAISE;
   END;
   SELECT id INTO part_id
   FROM Part
   WHERE name = name_id
    AND parent = parent_id
    AND version = inVersion
    AND serial IS NULL
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 version_id := (SELECT GetVersionName(inVersionName));
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar,
 inMajor  varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 IF inVersionName IS NOT NULL THEN
  version_id := (SELECT GetVersionName(inVersionName, inMajor, NULL, NULL));
 ELSE
  version_id := (SELECT GetVersion(inMajor, NULL, NULL));
 END IF;
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar,
 inMajor  varchar,
 inMinor varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 IF inVersionName IS NOT NULL THEN
  version_id := (SELECT GetVersionName(inVersionName, inMajor, inMinor, NULL));
 ELSE
  version_id := (SELECT GetVersion(inMajor, inMinor, NULL));
 END IF;
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersionName varchar,
 inMajor  varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE version_id integer;
BEGIN
 IF inVersionName IS NOT NULL THEN
  version_id := (SELECT GetVersionName(inVersionName, inMajor, inMinor, inPatch));
 ELSE
  version_id := (SELECT GetVersion(inMajor, inMinor, inPatch));
 END IF;
 RETURN (
  SELECT GetPart(inName, version_id)
 );
END;
$$ LANGUAGE plpgsql;

-- Pass in the parent part that will be copied to new part with serial number
CREATE OR REPLACE FUNCTION GetPartbySerial (
 inParent integer,
 inSerial varchar
) RETURNS integer AS $$
DECLARE
 part_id integer;
BEGIN
 IF inParent IS NOT NULL THEN
  SELECT part.id INTO part_id
  FROM Part
  WHERE Part.parent = inParent
   AND Part.serial = inSerial
  LIMIT 1;
  IF part_id IS NULL THEN
   -- Be sure to process any single part one at a time without the need of a transaction or locking Part table
   PERFORM pg_advisory_lock(inParent);
   BEGIN
   INSERT INTO Part (parent, name, version, serial) (
    SELECT inParent, parent.name, parent.version, inSerial
    FROM Part AS parent
    LEFT JOIN Part AS exists ON exists.parent = inParent
     AND exists.serial = inSerial
    WHERE parent.id = inParent
     AND exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inParent);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inParent);
     RAISE;
   END;
   SELECT part.id INTO part_id
   FROM Part
   WHERE Part.parent = inParent
    AND Part.serial = inSerial
   LIMIT 1;
  END IF;
 END IF;
 RETURN part_id;
END;
$$ LANGUAGE plpgsql;

-- Used in other GetAssembly functions
CREATE OR REPLACE FUNCTION PutAssemblyPart (
 inAssembly integer,
 inPart integer,
 inDesignator varchar,
 inQuantity integer
) RETURNS void AS $$
DECLARE designator_id integer;
BEGIN
 IF inAssembly IS NOT NULL THEN
  designator_id := GetWord(inDesignator);
  -- Be sure to process any single assembly one at a time without the need of a transaction or locking AssemblyPart table
  PERFORM pg_advisory_lock(inAssembly);
  BEGIN
  INSERT INTO AssemblyPart (assembly, part, designator, quantity) (
   SELECT inAssembly, inPart, designator_id, inQuantity
   FROM Dual
   LEFT JOIN AssemblyPart AS exists ON exists.assembly = inAssembly
    AND exists.part = inPart
    AND ((exists.designator = designator_id) OR (exists.designator IS NULL AND designator_id IS NULL))
    AND ((exists.quantity = inQuantity) OR (exists.quantity IS NULL AND inQuantity IS NULL))
   WHERE exists.assembly IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(inAssembly);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inAssembly);
    RAISE;
  END;
 END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION PutAssemblyPart (
 inAssemblyName varchar,
 inAssemblyVersion varchar,
 inAssemblyMajor  varchar,
 inAssemblyMinor varchar,
 inAssemblyPatch varchar,
 inPartName varchar,
 inPartVersion varchar,
 inPartMajor  varchar,
 inPartMinor varchar,
 inPartPatch varchar,
 inDesignator varchar,
 inQuantity integer
) RETURNS void AS $$
DECLARE
 assembly_id integer;
 part_id integer;
BEGIN
 assembly_id := GetPart(inAssemblyName, inAssemblyVersion, inAssemblyMajor, inAssemblyMinor, inAssemblyPatch);
 part_id := GetPart(inPartName, inPartVersion, inPartMajor, inPartMinor, inPartPatch);
 PERFORM PutAssemblyPart(assembly_id, part_id, inDesignator, inQuantity);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAssemblyApplicationRelease (
 inAssembly integer,
 inApplicationRelease integer,
 inParent integer
) RETURNS integer AS $$
DECLARE
 assemblyapplicationrelease_id integer;
BEGIN
 IF inAssembly IS NOT NULL AND inApplicationRelease IS NOT NULL THEN
  SELECT id INTO assemblyapplicationrelease_id
  FROM AssemblyApplicationRelease
  WHERE assembly = inAssembly
   AND applicationRelease = inApplicationRelease
   AND ((parent = inParent) OR (parent IS NULL AND inParent IS NULL))
  LIMIT 1;
  -- Be sure to process any single assmbly application release one at a time without the need of a transaction or locking AssemblyApplicationRelease table
  IF assemblyapplicationrelease_id IS NULL THEN
   PERFORM pg_advisory_lock(inAssembly);
   BEGIN
   INSERT INTO AssemblyApplicationRelease (parent, assembly, applicationRelease) (
    SELECT inParent AS parent, inAssembly AS assembly, inApplicationRelease AS applicationRelease
    FROM Dual
    LEFT JOIN AssemblyApplicationRelease AS exists ON exists.assembly = inAssembly
     AND exists.applicationRelease = inApplicationRelease
     AND ((exists.parent = inParent) OR (exists.parent IS NULL AND inParent IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inAssembly);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inAssembly);
     RAISE;
   END;
   SELECT id INTO assemblyapplicationrelease_id
   FROM AssemblyApplicationRelease
   WHERE assembly = inAssembly
    AND applicationRelease = inApplicationRelease
    AND ((parent = inParent) OR (parent IS NULL AND inParent IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN assemblyapplicationrelease_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAssemblyApplicationRelease (
 inAssembly integer,
 inApplicationRelease integer
) RETURNS integer AS $$
BEGIN
RETURN (SELECT GetAssemblyApplicationRelease(inAssembly, inApplicationRelease, NULL));
END;
$$ LANGUAGE plpgsql;



-- Web Session / Agent (diagram: web_session)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION RandomString (
 inLength integer
) RETURNS varchar AS $$
DECLARE
 base_chars varchar[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
 base integer := 62;
 x integer;
 result_string varchar;
BEGIN
 IF inLength > 0 THEN
  result_string := '';
  FOR x IN 1..inLength LOOP
   result_string := result_string || base_chars[ceiling(random()*base)];
  END LOOP;
 END IF;
 RETURN result_string;
END;
$$ LANGUAGE plpgsql;

-- Returns an AssemblyApplicationRelease id for device, os and application.  OS is the parent.
CREATE OR REPLACE FUNCTION GetDeviceOSApplicationRelease (
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar
) RETURNS integer AS $$
DECLARE
 deviceName VARCHAR;
 deviceId integer;
 deviceVersionId integer;
BEGIN
 deviceName := (SELECT COALESCE(inDeviceFamily, 'Unknown'));
 -- User Device Agent SessionCredential.agent field, references AssemblyApplicationRelease.id
 -- Detect device family version
 IF inDeviceFamilyVersion IS NOT NULL THEN
  deviceVersionId := (SELECT GetVersionName(inDeviceFamilyVersion, NULL, NULL, NULL));
  deviceId := (SELECT GetPart(deviceName, deviceVersionId));
 ELSE
  deviceId := (SELECT GetPart(deviceName));
 END IF;

 RETURN (SELECT GetAssemblyApplicationRelease(
   -- device
   deviceId,
   -- application release id
   GetApplicationRelease(
    -- application id
    GetApplication(inUAfamily),
    -- application release
    GetRelease(
     -- application version
     GetVersion(inUAmajor,inUAminor,inUApatch),
     inUAbuild)
   ),
   -- device os
   GetAssemblyApplicationRelease(
    --device
    deviceId,
    --os release id
    GetApplicationRelease(
     -- os id
     GetApplication(inOSfamily),
     -- os release
     GetRelease(
      -- os version
      GetVersionName(inOSfamily, inOSmajor, inOSminor, inOSpatch)
     )
    )
   )
  )
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetDeviceOSApplicationRelease (
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar
) RETURNS integer AS $$
BEGIN
RETURN (
 SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild, inOSfamily, inOSmajor, inOSminor, inOSpatch, inDeviceBrand, inDeviceModel, inDeviceFamily, NULL)
);
END;
$$ LANGUAGE plpgsql;

-- The function GetAgentString(inUAstring) can be used instead of a cache if the DB is fast enough
-- If all but sentence are null, then the parsed inUAstring needs to be inserted using GetDeviceOSApplicationRelease and GetAgentString(inAgent, inString)
-- agentstring can be used in SetSession calls
-- agentstring can be stored in a cache and looked up with inUAstring
CREATE OR REPLACE FUNCTION GetAgentString (
 inUAstring varchar
) RETURNS TABLE (agentstring integer,
 assemblyapplicationrelease integer, sentence integer,
 device varchar, os varchar, agent varchar) AS $$
DECLARE string_id integer;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));
 -- Does not actually insert an AgentString record.  Will return a NULL agentstring if a parsed agents string does not yet exist
 RETURN QUERY (
  SELECT AgentString.id AS agentstring,
   AgentString.agent, Sentence.id AS sentence,
   ParsedAgentStringShort.device,
   ParsedAgentStringShort.os,
   ParsedAgentStringShort.agent
  FROM Sentence
  LEFT JOIN AgentString ON AgentString.userAgentString = Sentence.id
  LEFT JOIN ParsedAgentStringShort ON ParsedAgentStringShort.agentstring = AgentString.id
  WHERE Sentence.culture IS NULL
   AND Sentence.id = string_id
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetAgentString (
 inAgent integer,
 inString integer
) RETURNS integer AS $$
DECLARE
 agentstring_id integer;
BEGIN
 IF inString IS NOT NULL THEN
  SELECT id INTO agentstring_id
  FROM AgentString
  WHERE userAgentString = inString
   AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
  LIMIT 1;
  IF agentstring_id IS NULL THEN
   -- Be sure to process any single agent string one at a time without the need of a transaction or locking AgentString table
   PERFORM pg_advisory_lock(inString);
   BEGIN
   INSERT INTO AgentString (agent,userAgentString) (
    SELECT inAgent, inString
    FROM Dual
    LEFT JOIN AgentString AS exists ON exists.userAgentString = inString
     AND ((exists.agent = inAgent) OR (exists.agent IS NULL AND inAgent IS NULL))
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inString);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(inString);
     RAISE;
   END;
   SELECT id INTO agentstring_id
   FROM AgentString
   WHERE userAgentString = inString
    AND ((agent = inAgent) OR (agent IS NULL AND inAgent IS NULL))
   LIMIT 1;
  END IF;
 END IF;
 RETURN agentstring_id;
END;
$$ LANGUAGE plpgsql;

-- Consider https://github.com/ua-parser to parse the user agent string
-- Sessions without or before authentication
-- First check memory cache for a agent id before parsing and sending to this function.
-- If found then call AnonymousSession(agentString_id, device_agent_id, 0,'www.ibm.com',NULL,NULL, '107.77.97.52');
-- Using ClientDo as an example
-- SELECT AnonymousSession('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36','Chrome','43','0','2357','130','Linux',NULL,NULL,NULL,NULL,NULL,'Other',0,'www.ibm.com',NULL,NULL,'107.77.97.52');
CREATE OR REPLACE FUNCTION AnonymousSession (
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS bigint AS $$
DECLARE
 string_id INTEGER;
 deviceAgent_id INTEGER;
 deviceName VARCHAR;
 agentString_id INTEGER;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));

 deviceAgent_id = (SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion));

 agentString_id = (SELECT GetAgentString(deviceAgent_id, string_id));

 RETURN (
  SELECT AnonymousSession(agentString_id, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress)
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AnonymousSession (
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS bigint AS $$
BEGIN
 RETURN (
  SELECT AnonymousSession(inUAstring, inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild, inOSfamily, inOSmajor, inOSminor, inOSpatch, inDeviceBrand, inDeviceModel, inDeviceFamily, NULL, inRefSecure, inRefHost, inRefPath, inRefGet, inIPAddress)
 );
END;
$$ LANGUAGE plpgsql;

-- SELECT AnonymousSession(1, 0,'www.ibm.com',NULL,NULL,'107.77.97.52');
CREATE OR REPLACE FUNCTION AnonymousSession (
 inAgentString INTEGER,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet
) RETURNS bigint AS $$
DECLARE
 existingSession bigint;
 referringURL integer;
BEGIN

 referringURL := GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet);

 existingSession := (
  SELECT session
  FROM SessionCredential
  WHERE credential IS NULL
  AND agentString = inAgentString
  AND fromAddress = inIPAddress
  AND ((referring = referringURL) OR (referring IS NULL AND referringURL IS NULL))
  LIMIT 1
 );

 IF existingSession IS NULL THEN
  INSERT INTO Session (lock) VALUES (0) RETURNING id INTO existingSession;

  -- Associate a remote client and remote IP address to a session
  INSERT INTO SessionCredential (session,agentString,fromAddress,referring)
  SELECT existingSession AS session, inAgentString AS agentString,
   inIPAddress AS fromAddress, referringURL
  ;
 ELSE
  UPDATE Session SET touched = NOW() WHERE id = existingSession;
 END IF;

 RETURN existingSession;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION SetSession (
 inSession varchar,
 inSiteApplicationRelease integer,
 inCredential integer,
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersioin varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet,
 inLocation integer
) RETURNS bigint AS $$
BEGIN
 RETURN (SELECT SetSession(inSession,inSiteApplicationRelease,inCredential,inUAstring,inUAfamily,inUAmajor,inUAminor,inUApatch,inUAbuild,inOSfamily,inOSmajor,inOSminor,inOSpatch,inDeviceBrand,inDeviceModel,inDeviceFamily,inDeviceFamilyVersion,inRefSecure,inRefHost,inRefPath,inRefGet,inIPAddress,inLocation,NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inCredential integer,
 -- User Agent
 inUAstring varchar,
 inUAfamily varchar,
 inUAmajor varchar,
 inUAminor varchar,
 inUApatch varchar,
 inUAbuild varchar,
 -- Operating System
 inOSfamily varchar,
 inOSmajor varchar,
 inOSminor varchar,
 inOSpatch varchar,
 -- Device
 inDeviceBrand varchar,
 inDeviceModel varchar,
 inDeviceFamily varchar,
 inDeviceFamilyVersion varchar,
 -- Referring
 inRefSecure integer,
 inRefHost varchar,
 inRefPath varchar,
 inRefGet varchar,
 -- Connection
 inIPAddress inet,
 inLocation integer,
 inStart timestamp
) RETURNS bigint AS $$
DECLARE
 string_id INTEGER;
 deviceAgent_id INTEGER;
 deviceName VARCHAR;
 agentString_id INTEGER;
 referring_id INTEGER;
BEGIN
 string_id := (SELECT GetIdentityPhrase(inUAstring));

 deviceAgent_id = (SELECT GetDeviceOSApplicationRelease(inUAfamily, inUAmajor, inUAminor, inUApatch, inUAbuild,
  inOSfamily, inOSmajor, inOSminor, inOSpatch,
  inDeviceBrand, inDeviceModel, inDeviceFamily, inDeviceFamilyVersion));

 agentString_id = (SELECT GetAgentString(deviceAgent_id, string_id));

 referring_id = (SELECT GetUrl(inRefSecure,inRefHost,inRefPath,inRefGet));

 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, agentString_id, inCredential, referring_id, inIPAddress, inLocation, inStart));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inAgentString integer,
 inCredential integer,
 inReferring integer,
 inIPAddress inet,
 inLocation integer
) RETURNS bigint AS $$
BEGIN
 RETURN (SELECT SetSession(inSessionToken, inSiteApplicationRelease, inAgentString, inCredential, inReferring, inIPAddress, inLocation, NULL));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetSession (
 inSessionToken varchar,
 inSiteApplicationRelease integer,
 inAgentString integer,
 inCredential integer,
 inReferring integer,
 inIPAddress inet,
 inLocation integer,
 inStart timestamp
) RETURNS bigint AS $$
DECLARE
 newSession bigint;
 existingSession bigint;
BEGIN
 IF inSessionToken IS NOT NULL THEN
  -- Does a session already exist for this token and site application release
  existingSession := (
   SELECT session
   FROM SessionToken
   WHERE token = inSessionToken
    AND (
     (siteApplicationRelease = inSiteApplicationRelease)
      OR (siteApplicationRelease IS NULL AND inSiteApplicationRelease IS NULL)
    )
   LIMIT 1
  );

  IF existingSession IS NULL THEN
   PERFORM pg_advisory_lock(hashtext(inSessionToken));
   BEGIN
   INSERT INTO Session (lock) VALUES (0) RETURNING id INTO existingSession;
   INSERT INTO SessionToken (session,token,siteApplicationRelease,created) (
    SELECT existingSession, inSessionToken, inSiteApplicationRelease, COALESCE(inStart, NOW()) AS created
   );
   PERFORM pg_advisory_unlock(hashtext(inSessionToken));
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(hashtext(inSessionToken));
     RAISE;
   END;
  ELSE
   UPDATE Session SET touched = NOW() WHERE id = existingSession;
  END IF;

  -- Be sure to process any single session credential one at a time without the need of a transaction or locking SessionCredential table
  PERFORM pg_advisory_lock(existingSession);
  BEGIN
  INSERT INTO SessionCredential (session, agentString, credential, referring, fromAddress, location) (
   SELECT existingSession, inAgentString, inCredential, inReferring, inIPAddress, inLocation
   FROM Dual
   LEFT JOIN SessionCredential AS exists ON exists.session = existingSession
    AND ((agentString = inAgentString) OR (agentString IS NULL AND inAgentString IS NULL))
    AND ((credential = inCredential) OR (credential IS NULL AND inCredential IS NULL))
    AND ((referring = inReferring) OR (referring IS NULL AND inReferring IS NULL))
    AND ((fromAddress = inIPAddress) OR (fromAddress IS NULL AND inIPAddress IS NULL))
    AND ((location = inLocation) OR (location IS NULL AND inLocation IS NULL))
   WHERE exists.id IS NULL
   LIMIT 1
  );
  PERFORM pg_advisory_unlock(existingSession);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(existingSession);
    RAISE;
  END;

 END IF;
 RETURN existingSession;
END;
$$ LANGUAGE plpgsql;



-- DAG edges / vertices (diagram: dag)
-- Assembled in lexicographic order of this directory; see README.md

-- DAG https://www.codeproject.com/Articles/22824/A-Model-to-Represent-Directed-Acyclic-Graphs-DAG-o
CREATE OR REPLACE FUNCTION AddEdge(v_start int, v_stop int) RETURNS integer AS $$
DECLARE
	v_id int;
BEGIN
	-- can't start and stop at the same place
	IF v_start = v_stop THEN
		RAISE NOTICE 'Start != Stop';
		RETURN NULL;
	END IF;

	-- detect duplicate
	PERFORM id FROM edge
	WHERE start = v_start
	AND stop = v_stop
	AND hops = 0;
	IF found THEN
		RAISE NOTICE 'Duplicate, (%,%) already exists',v_start,v_stop;
		RETURN NULL; -- found duplicate
	END IF;

	-- detect circular relation attempt
	PERFORM id FROM edge
	WHERE start = v_stop
	AND stop = v_start;
	IF found THEN
		RAISE NOTICE 'Circular relation rejected';
		RETURN NULL; -- found circular conflict
	END IF;

	-- insert 0 hop edge
	INSERT INTO edge (
		id,
		start, stop,
		entry, direct, exit)
	VALUES (
		nextval('edge_id_seq'),
		v_start,
		v_stop,
		currval('edge_id_seq'),
		currval('edge_id_seq'),
		currval('edge_id_seq')
	);

	v_id := currval('edge_id_seq');

	-- Connect graphs A (start) and B (stop) together
	-- Step 1: A's incoming edges to B
	INSERT INTO edge (
		start, stop,
		hops,
		entry, direct, exit)
	SELECT
		start,
		v_stop,
		hops + 1,
		id,
		v_id,
		v_id
	FROM edge
	WHERE stop = v_start;

	-- Step 2: A to B's outgoing edges
	INSERT INTO edge (
		start, stop,
		hops,
		entry, direct, exit)
	SELECT
		v_start,
		stop,
		hops + 1,
		v_id,
		v_id,
		id
	FROM edge
	WHERE start = v_stop;

	-- Step 3: A's incoming edges to the stop node of B's outgoing edges
	INSERT INTO edge (
		start, stop,
		hops,
		entry, direct, exit)
	SELECT
		A.start,
		B.stop,
		A.hops + B.hops + 2,
		A.id,
		v_id,
		B.id
	FROM edge A CROSS JOIN edge B
	WHERE A.stop = v_start
	AND B.start = v_stop;

	RETURN v_id;
END
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION RemoveEdge(v_start int, v_stop int) RETURNS integer AS $$
DECLARE
	v_id int;
	v_count int;
BEGIN
	-- detect if it actually exists
	SELECT id INTO v_id FROM edge
		WHERE start = v_start
		AND stop = v_stop
		AND hops = 0;
	IF found THEN
		-- continue processing
	ELSE
		RAISE NOTICE 'Relation (%,%) does not exists',v_start,v_stop;
		RETURN NULL;
	END IF;

	CREATE TEMPORARY TABLE purgeList (id int);

	-- Step 1: rows that were originally inserted for this direct edge
	INSERT INTO purgeList
		SELECT id
		FROM edge
		WHERE direct = v_id;

	-- Step 2: scan and find all dependent rows that are inserted after first
	LOOP
		INSERT INTO purgeList
		SELECT id FROM edge
		WHERE hops > 0
		AND (entry IN (SELECT id FROM purgeList)
			OR exit IN (SELECT id FROM purgeList))
		AND id NOT IN (SELECT id FROM purgeList);
		EXIT WHEN NOT found;
	END LOOP;

	-- count the records to be deleted and then delete them
	SELECT count(id) INTO v_count FROM purgeList;
	DELETE FROM edge
	WHERE id IN (SELECT id FROM purgeList);

	DROP TABLE purgeList;

	RETURN v_count;
END
$$ LANGUAGE plpgsql;

-- Can Return NULL
CREATE OR REPLACE FUNCTION GetVertex (
 inVertexName varchar
) RETURNS integer AS $$
BEGIN
 RETURN (
  SELECT vertex
  FROM VertexName
  WHERE VertexName.name = GetSentence(inVertexName)
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddEdgeName (
 inStart varchar,
 inStop  varchar
) RETURNS integer AS $$
DECLARE
 v_start integer;
 v_stop  integer;
BEGIN
 v_start := GetVertex(inStart);
 IF v_start IS NULL THEN
  INSERT INTO VertexName (name) VALUES (GetSentence(inStart)) RETURNING vertex INTO v_start;
 END IF;

 v_stop := GetVertex(inStop);
 IF v_stop IS NULL THEN
  INSERT INTO VertexName (name) VALUES (GetSentence(inStop)) RETURNING vertex INTO v_stop;
 END IF;

 RETURN AddEdge(v_start, v_stop);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION RemoveEdgeName (
 inStart varchar,
 inStop  varchar
) RETURNS integer AS $$
DECLARE
 v_start integer;
 v_stop  integer;
 v_count integer;
BEGIN
 v_start := GetVertex(inStart);
 v_stop  := GetVertex(inStop);

 IF v_start IS NOT NULL AND v_stop IS NOT NULL THEN
  v_count := (SELECT RemoveEdge(v_start, v_stop));
 END IF;

 RETURN v_count;
END
$$ LANGUAGE plpgsql;

-- Can return NULL
CREATE OR REPLACE FUNCTION GetIndividualVertex (
 inIndividual bigint,
 inVertex  integer
) RETURNS integer AS $$
BEGIN

 RETURN (
  SELECT VertexName.vertex
  FROM IndividualVertex
  JOIN VertexName ON VertexName.vertex = inVertex
  JOIN Edge ON Edge.start = inVertex
  WHERE IndividualVertex.individual = inIndividual
  ORDER BY Edge.hops ASC
  LIMIT 1
 );
END
$$ LANGUAGE plpgsql;

-- Can return NULL
CREATE OR REPLACE FUNCTION GetIndividualVertex (
 inIndividual bigint
) RETURNS integer AS $$
BEGIN

 RETURN (
  SELECT VertexName.vertex
  FROM IndividualVertex
  JOIN VertexName ON VertexName.vertex = IndividualVertex.vertex
  LEFT JOIN Edge ON Edge.start = IndividualVertex.vertex
  WHERE IndividualVertex.individual = inIndividual
  ORDER BY Edge.hops ASC
  LIMIT 1
 );
END
$$ LANGUAGE plpgsql;

-- Vertex without a name
CREATE OR REPLACE FUNCTION CreateVertex (
) RETURNS integer AS $$
DECLARE
 v_id integer;
BEGIN
 INSERT INTO VertexName (name) VALUES (NULL) RETURNING vertex INTO v_id;

 RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SetIndividualVertex (
 inIndividual bigint,
 inType varchar
) RETURNS integer AS $$
DECLARE
 v_id integer;
 t_id integer;
BEGIN

 v_id := GetIndividualVertex(inIndividual);
 IF inType IS NOT NULL AND inType != '' THEN
  t_id := GetIdentifier(inType);
 END IF;

 -- Create no-name Vertex
 IF v_id IS NULL THEN
  v_id := CreateVertex();
  INSERT INTO IndividualVertex (individual, vertex, type) VALUES (inIndividual, v_id, t_id);
 END IF;

RETURN v_id;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION SetIndividualVertex (
 inIndividual bigint
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN SetIndividualVertex(inIndividual, NULL);
END
$$ LANGUAGE plpgsql;



-- Double Entry Accounting functions
--


-- Double-entry Book / Post (diagram: accounting)
-- Assembled in lexicographic order of this directory; see README.md

-- Drop functions thas use JournalEntryResult
DROP FUNCTION IF EXISTS Book(varchar, float);
DROP FUNCTION IF EXISTS Book(varchar, numeric);
DROP FUNCTION IF EXISTS Post(varchar, float, varchar);
DROP FUNCTION IF EXISTS Post(varchar, numeric, varchar);
DROP FUNCTION IF EXISTS Post(varchar, float, varchar, timestamp);
DROP FUNCTION IF EXISTS Post(varchar, numeric, varchar, timestamp);
--
DROP TYPE IF EXISTS JournalEntryResult CASCADE;
CREATE TYPE JournalEntryResult AS (
 journal INTEGER,
 entry INTEGER
);

--
-- Book single amounts into double entry Journal
CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount numeric
) RETURNS JournalEntryResult AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 -- Pickup book and journal to use
 SELECT book, journal
 INTO book_id, journal_id
 FROM BookName
 WHERE BookName.name = GetSentence(inBook)
 LIMIT 1
 ;

 -- Get a new unique entry_id
 INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

 INSERT INTO JournalEntry (journal, book, entry,  account, credit, amount)
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  NOT increaseCredit AS credit,
  (inAmount * increaseCreditIncrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseCreditIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  increase AS account,
  increaseCredit AS credit,
  (inAmount * increaseDebitIncrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * increaseDebitIncrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  NOT decreaseCredit AS credit,
  (inAmount * decreaseCreditDecrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseCreditDecrease IS NOT NULL
 UNION ALL
 SELECT journal,
  book,
  entry_id AS entry,
  decrease AS account,
  decreaseCredit AS credit,
  (inAmount * decreaseDebitDecrease) * split AS amount
 FROM Books
 WHERE Books.book = book_id
  AND inAmount * decreaseDebitDecrease IS NOT NULL
 ;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

-- Book and return new balances
CREATE OR REPLACE FUNCTION BookBalance (
 inBook varchar,
 inAmount numeric
) RETURNS TABLE (
 book integer,
 entry integer,
 account integer,
 nameId integer,
 name varchar,
 rightside boolean,
 type integer,
 typeName varchar,
 debit numeric,
 credit numeric
) AS $$
DECLARE
 book_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 book_id := (
  SELECT BookName.book
  FROM BookName
  WHERE BookName.name = GetSentence(inBook)
  LIMIT 1
 );

 SELECT * INTO journal_id, entry_id FROM Book(inBook, inAmount);

 RETURN QUERY
  SELECT book_id AS book,
   entry_id AS entry,
   Transactions.account,
   AccountName.name AS nameId,
   Sentence.value AS name,
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
    WHERE JournalEntry.entry = entry_id
     AND posted IS NULL
   ) AND JournalEntry.posted IS NULL
  ) AS Transactions
  JOIN AccountName ON AccountName.account = Transactions.account
  JOIN Word ON Word.id = AccountName.type
   AND Word.culture = 1033
  JOIN Sentence ON Sentence.id = AccountName.name
   AND Sentence.culture = 1033
  GROUP BY Transactions.account, AccountName.name, AccountName.credit, AccountName.type, Word.value, Sentence.value
  ;
END;
$$ LANGUAGE plpgsql;

-- Post a balanced General Journal entry
CREATE OR REPLACE FUNCTION Post (
 inDebitAccount varchar,
 inAmount numeric,
 inCreditAccount varchar,
 inDateTime timestamp
) RETURNS JournalEntryResult AS $$
DECLARE
 journal_name varchar;
 journal_id integer;
 credit_account_id integer;
 debit_account_id integer;
 entry_id integer;
BEGIN
 journal_name := 'General';

 IF inDateTime IS NULL THEN
  inDateTime := CAST(NOW() AS date);
 END IF;

 SELECT journal
 INTO journal_id
 FROM JournalName
 JOIN Sentence ON Sentence.id = JournalName.name
 WHERE Sentence.value = journal_name
 LIMIT 1
 ;

 SELECT account
 INTO credit_account_id
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inCreditAccount
 LIMIT 1
 ;

 SELECT account
 INTO debit_account_id
 FROM AccountName
 JOIN Sentence ON Sentence.id = AccountName.name
 WHERE Sentence.value = inDebitAccount
 LIMIT 1
 ;

 IF journal_id IS NOT NULL AND credit_account_id IS NOT NULL AND debit_account_id IS NOT NULL THEN
  -- Get a new unique entry_id
  INSERT INTO Entry (assemblyApplicationRelease,credential) VALUES (NULL, NULL) RETURNING id INTO entry_id;

  -- Balanced entries
  INSERT INTO JournalEntry (journal, entry, account, credit, amount, created)
  VALUES (journal_id, entry_id, credit_account_id, true, inAmount, inDateTime);
  INSERT INTO JournalEntry (journal, entry, account, credit, amount, created)
  VALUES (journal_id, entry_id, debit_account_id, false, inAmount, inDateTime);
 END IF;

 RETURN ROW(journal_id, entry_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Post (
 inDebitAccount varchar,
 inAmount numeric,
 inCreditAccount varchar
) RETURNS JournalEntryResult AS $$
BEGIN
 RETURN Post(inCreditAccount, inAmount, inDebitAccount, NULL);
END;
$$ LANGUAGE plpgsql;


-- Inventory Movement
--

-- Bills / Cargo / Jobs / Schedule (diagram: inventory)
-- Assembled in lexicographic order of this directory; see README.md

CREATE OR REPLACE FUNCTION CreateBill (
 inSupplier bigint,
 inConsignee bigint,
 inType varchar,
 inParent integer
) RETURNS integer AS $$
DECLARE
 bill_id integer;
BEGIN
 INSERT INTO Bill (supplier, consignee, type, parent) VALUES (inSupplier, inConsignee, GetWord(inType), inParent) RETURNING id INTO bill_id;

 RETURN bill_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CreateBill (
 inSupplier bigint,
 inConsignee bigint,
 inType varchar
) RETURNS integer AS $$
BEGIN
 RETURN CreateBill (inSupplier, inConsignee, inType, NULL);
END;
$$ LANGUAGE plpgsql;


-- Can return NULL
-- Gets the oldest of type
CREATE OR REPLACE FUNCTION GetOutstandingBill (
 inSupplier bigint,
 inConsignee bigint,
 inType varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN (
  SELECT id
  FROM Bill
  WHERE supplier = inSupplier
   AND consignee = inConsignee
   AND type = GetWord(inType)
   AND received IS NULL
   AND loaded IS NULL
   AND clean IS NULL
   AND dirty IS NULL
  ORDER BY created ASC
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION GetBillReference (
  inBill integer,
  inType varchar,
  inValue character varying(80),
  inSequence smallint DEFAULT NULL
) RETURNS integer AS $$
DECLARE
  type_id integer;
  reference_id integer;
BEGIN
 IF inBill IS NULL OR inValue IS NULL OR TRIM(inValue) = '' THEN
  RETURN NULL;
 END IF;

 type_id := GetIdentifier(inType);

 -- Check for existing active reference
 SELECT id INTO reference_id
 FROM BillReference
 WHERE bill = inBill
  AND type = type_id
  AND value = inValue
  AND stop IS NULL
 LIMIT 1;

 IF reference_id IS NULL THEN
  PERFORM pg_advisory_lock(inBill);
  BEGIN
  INSERT INTO BillReference (bill, type, value, sequence) (
   SELECT inBill, type_id, inValue, inSequence
   FROM DUAL
   LEFT JOIN BillReference AS exists ON exists.bill = inBill
    AND exists.type = type_id
    AND exists.value = inValue
    AND exists.stop IS NULL
   WHERE exists.id IS NULL
   LIMIT 1
  ) RETURNING id INTO reference_id;
  PERFORM pg_advisory_unlock(inBill);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inBill);
    RAISE;
  END;
 ELSE
  -- Update sequence if provided and different
  IF inSequence IS NOT NULL THEN
   UPDATE BillReference
   SET sequence = inSequence
   WHERE id = reference_id
    AND sequence IS DISTINCT FROM inSequence;
  END IF;
 END IF;

 RETURN reference_id;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer,
 inFromCargo integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
 book_amount numeric;
BEGIN
 SELECT INTO cargo_id
  id AS cargo_id
 FROM Cargo
 WHERE bill = inBill
  AND assembly = inAssembly
  AND ((individualJob = inIndividualJob) OR (inIndividualJob IS NULL AND individualJob IS NULL))
  AND ((journal = inJournal) OR (inJournal IS NULL AND journal IS NULL))
  AND ((entry = inEntry) OR (inEntry IS NULL AND entry IS NULL))
 ORDER BY id DESC
 LIMIT 1
 ;

 IF inBook IS NULL THEN
  IF cargo_id IS NULL THEN
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT nextval('cargo_id_seq'),
    inBill,
    CASE WHEN inCount = 1 THEN
     NULL -- cargo record itself is a count of one unless overridden
    ELSE
     inCount
    END AS count,
    inAssembly,
    inIndividualJob,
    inJournal,
    inEntry
   FROM DUAL
   RETURNING id INTO cargo_id;
  ELSE
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT cargo_id,
    inBill,
    inCount,
    inAssembly,
    inIndividualJob,
    inJournal,
    inEntry
   FROM DUAL
   ;
  END IF;
 ELSE
  -- Book the current amount for the cargo
  -- Will not book any transactions if book_amount IS NULL
  book_amount := (
   SELECT totalPrice
   FROM LineItems
   WHERE line = inFromCargo
    AND ((part = inAssembly) OR (part IS NULL AND inAssembly IS NULL))
    -- Don't check individualJob since the default in LineItems may be newer
    -- Use the locked in individualJob from the inFromCargo's inIndividualJob
    AND totalPrice IS NOT NULL
   LIMIT 1
  );
  IF cargo_id IS NULL THEN
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT nextval('cargo_id_seq'),
    inBill,
    CASE WHEN inCount = 1 THEN
     NULL -- cargo record itself is a count of one unless overridden
    ELSE
     inCount
    END AS count,
    inAssembly,
    inIndividualJob,
    journal,
    entry
   FROM Book(inBook, book_amount)
   RETURNING id INTO cargo_id;
  ELSE
   INSERT INTO Cargo (id, bill, count, assembly, individualJob, journal, entry)
   SELECT cargo_id,
    inBill,
    inCount,
    inAssembly,
    inIndividualJob,
    journal,
    entry
   FROM Book(inBook, book_amount)
   ;
  END IF;
 END IF;

 IF inFromCargo IS NOT NULL THEN
  -- Create Cargo State records
  INSERT INTO CargoState (cargo, toCargo, count, journal, entry)
  VALUES (inFromCargo, cargo_id, inCount, inJournal, inEntry);
 END IF;

 RETURN cargo_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer,
 inFromCargo integer
) RETURNS integer AS $$
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, inIndividualJob, inJournal, inEntry, inFromCargo, NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, inIndividualJob, inJournal, inEntry, NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inUnit numeric,
 inIndividualJob integer,
 inFromCargo integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 -- Custom Book entry
 IF inBook IS NOT NULL AND inUnit IS NOT NULL THEN
   SELECT * INTO journal_id, entry_id FROM Book(inBook, inUnit * inCount);
 END IF;

 cargo_id := AddCargo(inBill, inAssembly, inCount, inIndividualJob, journal_id, entry_id, inFromCargo);

 RETURN cargo_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AddCargoAlternate (
 inBill integer,
 inAlternateAssembly integer,
 inCount float,
 inUnit numeric,
 inIndividualJob integer,
 inFromCargo integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
 entry_id integer;
 journal_id integer;
BEGIN
 -- Will create a custom CargoState entry, so inFromCargo is NULL on AddCargo Call
 -- Will also need to create a custom Booking
 -- Custom Book entry

 IF inBook IS NOT NULL AND inUnit IS NOT NULL THEN
   SELECT * INTO journal_id, entry_id FROM Book(inBook, inUnit * inCount);
 END IF;

 cargo_id := AddCargo(inBill, inAlternateAssembly, inCount, inIndividualJob, journal_id, entry_id);

 -- Custom CargoState entry
 INSERT INTO CargoState (cargo, toCargo, count, journal, entry)
 VALUES (inFromCargo, cargo_id, inCount, journal_id, entry_id);

 RETURN cargo_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, NULL, NULL, NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
BEGIN
IF inFromBill IS NOT NULL AND inToBill IS NOT NULL THEN
 PERFORM pg_advisory_lock(inFromBill);
 BEGIN
 IF inItem IS NULL THEN
  -- Move all remaining cargo to inToBill
  -- Use AddCargo
  PERFORM AddCargo(inToBill,
   Cargo.assembly,
   SUM(COALESCE(Cargo.count, 1)) - (
    CASE WHEN CargoState.cargo IS NOT NULL THEN
     SUM(COALESCE(CargoState.count, 1))
    ELSE
     0
    END
   ),
   COALESCE(inIndividualJob, Cargo.individualJob),
   Cargo.journal,
   Cargo.entry,
   Cargo.id,
   inBook)
  FROM Cargo
  LEFT JOIN CargoState ON CargoState.cargo = Cargo.id
  WHERE Cargo.bill = inFromBill
  GROUP BY Cargo.id,
   Cargo.assembly,
   Cargo.individualJob,
   Cargo.journal,
   Cargo.entry,
   CargoState.cargo
  HAVING SUM(COALESCE(Cargo.count, 1)) - (
    CASE WHEN CargoState.cargo IS NOT NULL THEN
     SUM(COALESCE(CargoState.count, 1))
    ELSE
     0
    END
   ) > 0
  ;
 ELSE
  -- Move single item cargo to inToBill
  -- Allow any count, even if more than inFromBill has
  PERFORM AddCargo(inToBill,
   inItem,
   inCount,
   COALESCE(inIndividualJob, Cargo.individualJob),
   Cargo.journal,
   Cargo.entry,
   Cargo.id,
   inBook)
  FROM Cargo
  WHERE Cargo.bill = inFromBill
   AND Cargo.assembly = inItem
  GROUP BY Cargo.id,
   Cargo.assembly,
   Cargo.individualJob,
   Cargo.journal,
   Cargo.entry
  ;
 END IF;
 PERFORM pg_advisory_unlock(inFromBill);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(inFromBill);
   RAISE;
 END;
END IF;
RETURN inToBill;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN MoveCargo(inFromBill, inToBill, inItem, inCount, inIndividualJob, NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float
) RETURNS integer AS $$
BEGIN
 RETURN MoveCargo(inFromBill, inToBill, inItem, inCount, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer,
 inBook varchar
) RETURNS integer AS $$
DECLARE
 to_bill integer;
BEGIN
 to_bill := (
  SELECT id
  FROM Bill
  WHERE Bill.parent = inFromBill
  LIMIT 1
 );

 RETURN MoveCargo(inFromBill, to_bill, inItem, inCount, inIndividualJob, inBook);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float,
 inIndividualJob integer
) RETURNS integer AS $$
DECLARE
 to_bill integer;
BEGIN
 RETURN MoveCargoToChild(inFromBill, inItem, inCount, inIndividualJob, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float
) RETURNS integer AS $$
BEGIN
 RETURN MoveCargoToChild(inFromBill, inItem, inCount, NULL);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetSchedule (
 inScheduleName varchar
) RETURNS integer AS $$
DECLARE
 scheduleName_id integer;
 schedule_id integer;
BEGIN
 IF inScheduleName IS NOT NULL THEN
   scheduleName_id := GetSentence(inScheduleName);
   SELECT schedule INTO schedule_id
   FROM ScheduleName
   WHERE name = scheduleName_id
   LIMIT 1;
   IF schedule_id IS NULL THEN
    -- Be sure to process any single schedule one at a time without the need of a transaction or locking ScheduleName table
    PERFORM pg_advisory_lock(scheduleName_id);
    BEGIN
    INSERT INTO ScheduleName (name) (
     SELECT scheduleName_id
     FROM DUAL
     LEFT JOIN ScheduleName AS exists ON exists.name = scheduleName_id
     WHERE exists.schedule IS NULL
     LIMIT 1
    ) RETURNING schedule INTO schedule_id;
    PERFORM pg_advisory_unlock(scheduleName_id);
    EXCEPTION
     WHEN OTHERS THEN
      PERFORM pg_advisory_unlock(scheduleName_id);
      RAISE;
    END;
    IF schedule_id IS NULL THEN
     schedule_id = (
      SELECT schedule
      FROM ScheduleName
      WHERE name = scheduleName_id
      LIMIT 1
     );
    END IF;
   END IF;
 END IF;
 RETURN schedule_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetJob (
 inJobName varchar
) RETURNS integer AS $$
DECLARE
 jobName_id integer;
 job_id integer;
BEGIN
 IF inJobName IS NOT NULL THEN
  jobName_id := GetSentence(inJobName);
  SELECT job INTO job_id
  FROM JobName
  WHERE name = jobName_id
  LIMIT 1;
  IF job_id IS NULL THEN
   -- Be sure to process any single job one at a time without the need of a transaction or locking JobName table
   PERFORM pg_advisory_lock(jobName_id);
   BEGIN
   INSERT INTO JobName (name) (
    SELECT jobName_id
    FROM DUAL
    LEFT JOIN JobName AS exists ON exists.name = jobName_id
    WHERE exists.job IS NULL
    LIMIT 1
   ) RETURNING job INTO job_id;
   PERFORM pg_advisory_unlock(jobName_id);
   EXCEPTION
    WHEN OTHERS THEN
     PERFORM pg_advisory_unlock(jobName_id);
     RAISE;
   END;
   IF job_id IS NULL THEN
    job_id = (
     SELECT job
     FROM JobName
     WHERE name = jobName_id
     LIMIT 1
    );
   END IF;
  END IF;
 END IF;
 RETURN job_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetIndividualJobSchedule (
 inIndividual bigint,
 inJob integer,
 inSchedule integer
) RETURNS integer AS $$
DECLARE individualJob_id integer;
BEGIN
 individualJob_id = (
  SELECT id
  FROM IndividualJob
  WHERE ((individual = inIndividual) OR (individual IS NULL AND inIndividual IS NULL))
   AND job = inJob
   AND schedule = schedule
   AND stop IS NULL
  LIMIT 1
 );
 IF individualJob_id IS NULL THEN
   INSERT INTO IndividualJob (id, individual, job, schedule)
   VALUES(nextval('individualjob_id_seq'), inIndividual, inJob, inSchedule)
   RETURNING id INTO individualJob_id;
 END IF;
 RETURN individualJob_id;
END;
$$ LANGUAGE plpgsql;



-- SchemaVersion helper
-- Assembled in lexicographic order of this directory; see README.md

-- Schema Mgmt Functions
--
CREATE OR REPLACE FUNCTION SetSchemaVersion (
 inSchemaName varchar,
 inMajor varchar,
 inMinor varchar,
 inPatch varchar
) RETURNS integer AS $$
DECLARE
 schema_id integer;
 version_id integer;
BEGIN
 IF inSchemaName IS NOT NULL THEN
  schema_id := (SELECT GetWord(inSchemaName));
  version_id := (SELECT GetVersion(inMajor, inMinor, inPatch));
 END IF;
 -- Always insert generating a build number
 INSERT INTO SchemaVersion (schema, version) VALUES (schema_id, version_id);
 -- Be sure this is the only active record
 UPDATE SchemaVersion SET stop = NOW()
 WHERE schema = schema_id
  AND version != version_id
 ;
 RETURN (SELECT currval(pg_get_serial_sequence('schemaversion','build')));
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Recreate views (dropped above for money ALTERs); from current schema.pgsql
-- ---------------------------------------------------------------------------
SET search_path TO business, public;

CREATE VIEW I18NWord ( id, defaultCulture, clientCulture, resultCulture, value ) AS

SELECT WordDefault.id,
 WordDefault.culture AS defaultCulture,
 ClientCulture() AS clientCulture,
 COALESCE(Word.culture, WordDefault.culture) AS resultCulture,
 COALESCE(Word.value, WordDefault.value) AS value
FROM Word AS WordDefault
LEFT JOIN Word ON Word.id = WordDefault.id
 AND Word.culture = ClientCulture()
WHERE WordDefault.culture = 1033

;

CREATE VIEW I18NSentence ( id, defaultCulture, clientCulture, resultCulture, value, length ) AS

SELECT SentenceDefault.id,
 SentenceDefault.culture AS defaultCulture,
 ClientCulture() AS clientCulture,
 COALESCE(Sentence.culture, SentenceDefault.culture) AS resultCulture,
 COALESCE(Sentence.value, SentenceDefault.value) AS value,
 COALESCE(Sentence.length, SentenceDefault.length) AS length
FROM Sentence AS SentenceDefault
LEFT JOIN Sentence ON Sentence.id = SentenceDefault.id
 AND Sentence.culture = ClientCulture()
WHERE SentenceDefault.culture = 1033

;

CREATE VIEW WordPlurals ( word, culture, zero, singular, two, few, many ) AS

SELECT Word.id AS word,
 Word.culture AS culture,
 COALESCE(WordFormZero.value, Word.value) AS zero,
 Word.value AS singular,
 COALESCE(WordFormTwo.value, WordFormFew.value, WordFormMany.value, Word.value) AS two,
 COALESCE(WordFormFew.value, WordFormMany.value, WordFormTwo.value, Word.value) AS few,
 COALESCE(WordFormMany.value, WordFormFew.value, WordFormTwo.value, Word.value) AS many
FROM Word
LEFT JOIN WordPlural AS WordPluralZero ON WordPluralZero.word = Word.id
 AND WordPluralZero.plural = 0
 AND WordPluralZero.culture = Word.culture
LEFT JOIN Word AS WordFormZero ON WordFormZero.id = WordPluralZero.form
 AND WordFormZero.culture = Word.culture
LEFT JOIN WordPlural AS WordPluralTwo ON WordPluralTwo.word = Word.id
 AND WordPluralTwo.plural = 2
 AND WordPluralTwo.culture = Word.culture
LEFT JOIN Word AS WordFormTwo ON WordFormTwo.id = WordPluralTwo.form
 AND WordFormTwo.culture = Word.culture
LEFT JOIN WordPlural AS WordPluralFew ON WordPluralFew.word = Word.id
 AND WordPluralFew.plural = 3
 AND WordPluralFew.culture = Word.culture
LEFT JOIN Word AS WordFormFew ON WordFormFew.id = WordPluralFew.form
 AND WordFormFew.culture = Word.culture
LEFT JOIN WordPlural AS WordPluralMany ON WordPluralMany.word = Word.id
 AND WordPluralMany.plural = 4
 AND WordPluralMany.culture = Word.culture
LEFT JOIN Word AS WordFormMany on WordFormMany.id = WordPluralMany.form
 AND WordFormMany.culture = Word.culture

;

CREATE VIEW People ( individual, name, goesBy, birthday, in_days, fullName, honorific, given, middle, family, suffix, post, honorificvalue, givenvalue, middlevalue, familyvalue, suffixvalue, postvalue, birth, death, aged, created ) AS

SELECT Individual.id AS individual, Name.id AS name,
 COALESCE(GoesBy.value,Given.value,Family.value) AS goesBy,
 birthday(CAST(birth AS date),CAST(NOW() AS date)) AS birthday,
 days_until_birthday(CAST(birth AS date), CAST(NOW() AS date)) AS in_days,
 COALESCE(Honorific.value,'') ||
  CASE WHEN (Honorific.value IS NOT NULL AND Given.value IS NULL AND Middle.value IS NULL) THEN ' ' ELSE '' END ||
  COALESCE(CASE WHEN (Honorific.value IS NOT NULL) THEN ' ' ELSE '' END || Given.value,'') ||
  COALESCE(CASE WHEN (Given.value IS NOT NULL) THEN ' ' ELSE '' END || Middle.value,'') ||
  CASE WHEN (Given.value IS NOT NULL AND Middle.value IS NULL) THEN ' ' ELSE '' END ||
  COALESCE(CASE WHEN (Middle.value IS NOT NULL) THEN ' ' ELSE '' END  || Family.value,'') ||
  COALESCE(CASE WHEN (Family.value IS NOT NULL) THEN ' ' ELSE '' END || Suffix.value,'') ||
  COALESCE(CASE WHEN (Suffix.value IS NOT NULL) THEN ' ' ELSE '' END || Post.value,'')
  AS fullName,
 Individual.prefix AS honorific,
 Name.given, Name.middle, Name.family,
 Individual.suffix,
 Individual.post,
 Honorific.value AS honorificValue,
 Given.value AS givenValue, Middle.value AS middleValue, Family.value AS familyValue,
 Suffix.value AS suffixValue,
 Post.value AS postValue,
 birth, death,
 COALESCE(age(death,birth),age(birth)) AS aged,
 Individual.created
FROM Individual
JOIN Name ON Name.id = Individual.name
LEFT JOIN Given ON Given.id = Name.given
LEFT JOIN Given AS Middle ON Middle.id = Name.middle
LEFT JOIN Given AS GoesBy ON GoesBy.id = Individual.goesBy
LEFT JOIN Family ON Family.id = Name.family
LEFT JOIN I18NWord AS Honorific ON Honorific.id = Individual.prefix
LEFT JOIN I18NWord AS Suffix ON Suffix.id = Individual.suffix
LEFT JOIN I18NWord AS Post ON Post.id = Individual.post
WHERE Individual.nameChange IS NULL
 OR Individual.nameChange > NOW()

;

CREATE VIEW IndividualPersonEvent ( individual, name, honorific, suffix, post, goesby, birth, death, event ) AS

SELECT DISTINCT Individual.id AS individual,
 Individual.name,
 COALESCE(Future.prefix, Individual.prefix) AS honorific,
 COALESCE(Future.suffix, Individual.suffix) AS suffix,
 COALESCE(Future.post, Individual.post) AS post,
 COALESCE(Future.goesBy, Individual.goesBy) AS goesBy,
 Individual.birth,
 Individual.death,
 CASE WHEN previous.id IS NULL THEN
  -- Check for single event
  CASE WHEN Future.id IS NULL THEN
   COALESCE(Individual.death,Individual.nameChange,Individual.birth)
  ELSE
   -- Check for individual attribute change only
   CASE WHEN (Future.goesBy != Individual.goesBy)
     OR (Future.goesBY IS NOT NULL AND Individual.goesBy IS NULL)
     OR (Future.goesBY IS NULL AND Individual.goesBy IS NOT NULL)
     OR (Future.prefix != Individual.prefix)
     OR (Future.prefix IS NOT NULL AND Individual.prefix IS NULL)
     OR (Future.prefix IS NULL AND Individual.prefix IS NOT NULL)
     OR (Future.suffix != Individual.suffix)
     OR (Future.suffix IS NOT NULL AND Individual.suffix IS NULL)
     OR (Future.suffix IS NULL AND Individual.suffix IS NOT NULL)
     OR (Future.post != Individual.post)
     OR (Future.post IS NOT NULL AND Individual.post IS NULL)
     OR (Future.post IS NULL AND Individual.post IS NOT NULL)
   THEN
    -- individual attriute change only
    Individual.nameChange
   ELSE
    Individual.birth
   END
  END
 ELSE
  CASE WHEN Future.id IS NULL THEN
   COALESCE(Individual.death,previous.nameChange,Individual.nameChange,Individual.birth)
  ELSE
   Individual.nameChange
  END
 END AS event
FROM Individual
CROSS JOIN Name
LEFT JOIN Individual AS previous ON previous.id = Individual.id
 AND (
  (COALESCE(previous.nameChange,previous.death) < COALESCE(Individual.nameChange,Individual.death))
  OR
  (Individual.death IS NULL AND Individual.nameChange IS NULL
   AND previous.nameChange IS NOT NULL)
 )
LEFT JOIN Individual AS Future ON Future.id = Individual.id
 AND COALESCE(Future.nameChange,Future.birth) >= COALESCE(Individual.nameChange,Individual.death)
 AND Future.death IS NULL
WHERE Name.id = Individual.name

;

CREATE VIEW PeopleEvent ( individual, name, goesby, fullname, date, event, eventname, honorific, given, middle, family, suffix, post, honorificvalue, givenvalue, middlevalue, familyvalue, suffixvalue, postvalue ) AS

SELECT IndividualPersonEvent.individual, IndividualPersonEvent.name,
 COALESCE(goesBy.value,Given.value,Family.value) AS goesBy,
 COALESCE(Honorific.value,'') ||
  CASE WHEN (Honorific.value IS NOT NULL AND Given.value IS NULL AND Middle.value IS NULL) THEN ' ' ELSE '' END ||
  COALESCE(CASE WHEN (Honorific.value IS NOT NULL) THEN ' ' ELSE '' END || Given.value,'') ||
  COALESCE(CASE WHEN (Given.value IS NOT NULL) THEN ' ' ELSE '' END || Middle.value,'') ||
  CASE WHEN (Given.value IS NOT NULL AND Middle.value IS NULL) THEN ' ' ELSE '' END ||
  COALESCE(CASE WHEN (Middle.value IS NOT NULL) THEN ' ' ELSE '' END  || Family.value,'') ||
  COALESCE(CASE WHEN (Family.value IS NOT NULL) THEN ' ' ELSE '' END || Suffix.value,'') ||
  COALESCE(CASE WHEN (Suffix.value IS NOT NULL) THEN ' ' ELSE '' END || Post.value,'')
  AS fullName,
 event AS date,
 COALESCE(Born.id, Death.id, Change.id) AS event,
 COALESCE(Born.value, Death.value, Change.value) AS eventName,
 IndividualPersonEvent.honorific,
 Name.given,
 Name.middle,
 Name.family,
 IndividualPersonEvent.suffix,
 IndividualPersonEvent.post,
 Honorific.value AS honorificValue,
 Given.value AS givenValue,
 Middle.value AS middleValue,
 Family.value AS familyValue,
 Suffix.value AS suffixValue,
 Post.value AS postValue
FROM IndividualPersonEvent
 JOIN Name ON Name.id = IndividualPersonEvent.name
 LEFT JOIN Given On Given.id = Name.given
 LEFT JOIN Given AS Middle ON Middle.id = Name.middle
 LEFT JOIN Given AS goesBy ON goesBy.id = IndividualPersonEvent.goesBy
 LEFT JOIN Family ON Family.id = Name.family
 LEFT JOIN I18NWord AS Honorific ON Honorific.id = IndividualPersonEvent.honorific
 LEFT JOIN I18NWord AS Suffix ON Suffix.id = IndividualPersonEvent.suffix
 LEFT JOIN I18NWord AS Post ON Post.id = IndividualPersonEvent.post
 LEFT JOIN I18NWord AS Born ON Born.value = 'Born' AND birth = event
 LEFT JOIN I18NWord AS Death ON Death.value = 'Died' AND death = event
 LEFT JOIN I18NWord AS Change ON Change.value = 'Changed name'

;

CREATE VIEW Entities ( individual, entity, goesBy, name, formed, location, dissolved, aged, created ) AS

SELECT Individual.id AS individual, Individual.entity, goesBy.value AS goesBy,
 Entity.name, Individual.birth AS formed,
 Individual.location,
 Individual.death AS dissolved,
 COALESCE(age(death,birth),age(birth)) AS aged,
 Individual.created
FROM Individual
JOIN Entity ON Entity.id = Individual.entity
LEFT JOIN Given AS goesBy ON goesBy.id = Individual.goesBy
WHERE Individual.nameChange IS NULL

;

CREATE VIEW List ( id, individual, listName, listNameValue, listSet, listSetValue, sequence, send, created ) AS

SELECT ListIndividual.id,
 ListIndividual.individual,
 ListIndividualName.name AS listName,
 Name.value AS listNameValue,
 ListIndividualName.listSet,
 ListSet.value AS listSetValue,
 ListIndividualName.sequence,
 CASE WHEN SendField.value IS NULL THEN 'to' ELSE SendField.value END AS send,
 ListIndividual.created
FROM ListIndividual
JOIN ListIndividualName ON ListIndividualName.ListIndividual = ListIndividual.id
 AND ListIndividualName.optinStyle = 1
JOIN I18NWord AS Name ON ListIndividualName.name = Name.id
LEFT JOIN I18NWord AS ListSet ON ListIndividualName.listSet = ListSet.id
LEFT JOIN Word AS SendField ON SendField.id = ListIndividual.type
 AND SendField.culture IS NULL
LEFT JOIN ListIndividual AS disable ON disable.individual = ListIndividual.individual
 AND disable.id IS NULL
 AND disable.unlist IS NULL
WHERE disable.individual IS NULL
 AND ListIndividual.unlist IS NULL

;

CREATE VIEW EmailAddress ( email, username, plus, host, value ) AS

SELECT id AS email, username, plus, host,
 username ||
 COALESCE('+' || plus, '') ||
 '@' || host AS value
FROM Email

;

CREATE VIEW URL ( path, protocol, host, value, created ) AS

SELECT id AS path, protocol, host,
 protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host || '/' ||
 COALESCE(value,'') ||
 CASE WHEN get IS NULL
 THEN ''
 ELSE '?' || get
 END AS value,
 created
FROM Path

;

CREATE VIEW File ( path, protocol, host, value, file, created ) AS

SELECT id AS path, protocol, host,
 protocol ||
 ':///' ||
 COALESCE(value,'') ||
 CASE WHEN value IS NOT NULL
 THEN '/'
 ELSE ''
 END ||
 COALESCE(get,'')
 AS value,
 COALESCE(value,'') ||
 CASE WHEN value IS NOT NULL
 THEN '/'
 ELSE ''
 END ||
 COALESCE(get,'')
 AS file,
 created
FROM Path

;

CREATE VIEW IndividualURL ( individual, type, path, protocol, host, value, created ) AS

WITH latest (individual,type,created) AS (
 SELECT individual, type, MAX(created) AS created
 FROM IndividualPath
 WHERE IndividualPath.stop IS NULL
 GROUP BY individual, type
)
SELECT latest.individual, latest.type, Path.id AS path, Path.protocol, Path.host,
 Path.protocol ||
 CASE WHEN secure = 1 THEN 's' ELSE '' END ||
 '://' || host || '/' ||
 COALESCE(Path.value,'') ||
 CASE WHEN COALESCE(Path.get,IndividualPath.track) IS NULL
 THEN ''
 ELSE '?' ||
 COALESCE(Path.get,'') ||
 COALESCE(CASE WHEN (Path.get IS NOT NULL AND IndividualPath.track IS NOT  NULL) THEN '&' ELSE '' END ||  IndividualPath.track, '')
 END AS value,
 latest.created
FROM latest
JOIN IndividualPath ON IndividualPath.individual = latest.individual
 AND IndividualPath.type = latest.type
 AND IndividualPath.created = latest.created
JOIN Individual ON Individual.id = latest.individual
 AND Individual.nameChange IS NULL
JOIN Path ON Path.id = IndividualPath.path

;

CREATE VIEW IndividualEmailAddress ( individual, type, email, username, plus, host, value, created ) AS

WITH latest (individual,type,created) AS (
 SELECT individual, type, MAX(created) AS created
 FROM IndividualEmail
 WHERE IndividualEmail.stop IS NULL
 GROUP BY individual, type
)
SELECT latest.individual, latest.type, IndividualEmail.email, EmailAddress.username,
 EmailAddress.plus, EmailAddress.host, EmailAddress.value, latest.created
FROM latest
JOIN Individual ON Individual.id = latest.individual
 AND Individual.nameChange IS NULL
JOIN IndividualEmail ON IndividualEmail.individual = latest.individual
 AND IndividualEmail.type = latest.type
 AND IndividualEmail.created = latest.created
JOIN EmailAddress ON EmailAddress.email = IndividualEmail.email

;

CREATE VIEW Phones ( phone, country, location, area, number, idd, ndd, code, local, international ) AS

SELECT Phone.id AS phone, Phone.country, Phone.location,
 Phone.area, Phone.number, Country.idd, Country.ndd,
 Country.code,
 Phone.area || '-' || LEFT(number,3) || '-' || RIGHT(number,4) AS local,
 Country.idd || '-' || Country.ndd || '-' ||   Phone.area || '-' || LEFT(number,3) || '-' || RIGHT(number,4)AS international
FROM Phone
JOIN Country ON Country.id = Phone.country

;

CREATE VIEW Addresses ( address, line1, line2, line3, city, state, zipcode, postalcode, country, countrycode, marquee, location, latitude, longitude ) AS

SELECT Address.id AS address,
 line1, line2, line3,
 City.value AS city,
 COALESCE(UPPER(StateAbbr.value), State.value) AS state,
 Postal.code ||
 CASE WHEN (postalplus IS NOT NULL) THEN '-' ELSE '' END ||
 Address.postalplus AS zipcode,
 Postal.code AS postalcode,
 Country.id AS country,
 Country.code AS countrycode,
 COALESCE(AddressLocation.marquee, PostalLocation.marquee, CountryLocation.marquee) AS marquee,
 COALESCE(AddressLocation.id, PostalLocation.id, CountryLocation.id) AS location,
 COALESCE(AddressLocation.latitude, PostalLocation.latitude, CountryLocation.latitude) AS latitude,
 COALESCE(AddressLocation.longitude, PostalLocation.longitude, CountryLocation.longitude) AS longitude
FROM Address
JOIN Postal ON Postal.id = Address.postal
JOIN Country ON Country.id = Postal.country
JOIN I18NWord AS City ON City.id = Postal.city
JOIN I18NWord AS State ON State.id = Postal.state
LEFT JOIN I18NWord AS StateAbbr ON StateAbbr.id = Postal.stateAbbreviation
LEFT JOIN Location AS AddressLocation On AddressLocation.id = Address.location
LEFT JOIN Location AS PostalLocation ON PostalLocation.id = Postal.location
LEFT JOIN Location AS CountryLocation ON CountryLocation.id = Country.location

;

CREATE VIEW Versions ( version, name, value, major, minor, patch ) AS

SELECT Version.id AS version, name.value AS name,
 major.value ||
  COALESCE('.' || minor.value, '') ||
  COALESCE('.' || patch.value, '')
 AS value,
 major.value AS major,
 minor.value AS minor,
 patch.value AS patch
FROM Version
LEFT JOIN I18NWord AS name ON name.id = Version.name
LEFT JOIN I18NWord AS major ON major.id = Version.major
LEFT JOIN I18NWord AS minor ON minor.id = Version.minor
LEFT JOIN I18NWord AS patch ON patch.id = Version.patch

;

CREATE VIEW Applications ( application, name, goesby, path ) AS

   SELECT Application.id AS application,
    Name.value AS name,
    Application.goesBy,
    Application.path
   FROM Application
   JOIN I18NWord AS Name on Name.id = Application.name

;

CREATE VIEW ApplicationReleases ( applicationrelease, application, release, name, goesby, applicationpath, versionid, buildid, versionname, buildname ) AS

   SELECT ApplicationRelease.id AS applicationRelease,
    ApplicationRelease.application,
    ApplicationRelease.release,
    Applications.name,
    Applications.goesBy,
    Applications.path AS applicationPath,
    Release.version AS versionId,
    Release.build AS buildId,
    Versions.value as versionName,
    Build.value as buildName
   FROM ApplicationRelease
   JOIN Applications ON Applications.application = ApplicationRelease.application
   JOIN Release ON Release.id = ApplicationRelease.release
   JOIN Versions ON Versions.version = Release.version
   JOIN I18NWord AS Build ON Build.id = Release.build

;

CREATE VIEW ParsedAgentStringShort ( agentstring, deviceid, device, osid, os, agentid, agent, deviceversion, osapplicationrelease, agentapplicationrelease ) AS

SELECT AgentString.id AS agentString,
 device.id AS deviceid, deviceName.value AS device,
 OS.id AS osid, OSName.value AS OS,
 Agent.id AS agentid, AgentName.value AS agent,
 device.version AS deviceversion,
 deviceOS.applicationrelease AS osApplicationRelease,
 agentApplicationRelease.id AS agentApplicationRelease
FROM AgentString
JOIN AssemblyApplicationRelease AS deviceAgent ON deviceAgent.id = AgentString.agent
JOIN Part AS device ON device.id = deviceAgent.assembly
JOIN I18NSentence AS deviceName ON deviceName.id = device.name
JOIN AssemblyApplicationRelease AS deviceOS ON deviceOS.id = deviceAgent.parent
JOIN ApplicationRelease AS OSapplicationRelease ON OSapplicationRelease.id = deviceOS.applicationRelease
JOIN Application AS OS ON OS.id = OSapplicationRelease.application
JOIN I18NWord AS OSName ON OSName.id = OS.name
JOIN ApplicationRelease AS agentApplicationRelease ON agentApplicationRelease.id = deviceAgent.applicationRelease
JOIN Application AS Agent On Agent.id = agentApplicationRelease.application
JOIN I18NWord AS AgentName ON AgentName.id = Agent.name

;

CREATE VIEW ParsedAgentString ( agentstring, deviceid, deviceversion, device, deviceersionname, osid, osversion, os, osversionname, agentid, agentversion, agent, agentversionname ) AS

SELECT agentstring,
 deviceid, deviceversion, device, deviceversionname.value as deviceersionname,
 osid, OSRelease.version AS osversion, os, OSVersion.value AS osversionname,
 agentid, AgentVersion.version AS agentversion, agent, AgentVersion.value agentversionname
FROM ParsedAgentStringShort
JOIN ApplicationRelease AS OSApplicatonRelease ON OSApplicatonRelease.id = osapplicationrelease
JOIN ApplicationRelease AS AgentApplicationRelease ON AgentApplicationRelease.id = agentApplicationRelease
LEFT JOIN Versions AS deviceversionname ON deviceversionname.version = deviceversion
LEFT JOIN Release AS OSRelease ON OSRelease.id = OSApplicatonRelease.release
LEFT JOIN Versions AS OSVersion ON OSVersion.version = OSRelease.version
LEFT JOIN Release AS AgentRelease ON AgentRelease.id = AgentApplicationRelease.release
LEFT JOIN Versions AS AgentVersion ON AgentVersion.version = AgentRelease.version

;

CREATE VIEW Sessions ( session, token, siteapplicationrelease, agentstring, deviceid, device, osid, os, agentid, agent, referring, referrringurl, fromaddress, credential, individual, username, email, created, touched ) AS

SELECT Session.id AS session,
 SessionToken.token, SessionToken.siteapplicationrelease,
 SessionCredential.agentstring,
 deviceid, ParsedAgentStringShort.device, osid, ParsedAgentStringShort.os, agentid, ParsedAgentStringShort.agent,
 SessionCredential.referring, URL.value AS referrringURL,
 SessionCredential.fromaddress,
 SessionCredential.credential, Credential.individual,  Credential.username,
 EmailAddress.value AS email,
 COALESCE(SessionToken.created, Session.created) AS created, Session.touched
FROM Session
CROSS JOIN SessionCredential
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN ParsedAgentStringShort ON ParsedAgentStringShort.agentstring = SessionCredential.agentstring
LEFT JOIN Credential ON Credential.id = SessionCredential.credential
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email
LEFT JOIN URL ON URL.path = SessionCredential.referring
WHERE Session.id = SessionCredential.session

;

CREATE VIEW Parts ( part, parent, name, nameId, version, versionId, serial, created ) AS

SELECT Part.id AS part, Part.parent,
 I18NSentence.value AS name, Part.name AS nameId,
 CASE WHEN (Versions.name IS NOT NULL) THEN Versions.name ELSE '' END ||
 CASE WHEN (Versions.name IS NOT NULL) THEN ' ' ELSE '' END ||
 CASE WHEN (Versions.value IS NOT NULL) THEN Versions.value ELSE '' END AS version,
 Part.version AS versionId,
 Part.serial, Part.created
FROM Part
JOIN I18NSentence ON I18NSentence.id = Part.name
LEFT JOIN Versions ON Versions.version = Part.version

;

CREATE VIEW Assemblies ( assembly, parentName, name, version, versionName, serial ) AS

SELECT DISTINCT AssemblyPart.assembly, Parent.name AS parentName,
 Assemblies.name,
 Assemblies.versionId AS version, Assemblies.version as VersionName, Assemblies.serial
FROM AssemblyPart
JOIN Parts AS Assemblies ON Assemblies.part = AssemblyPart.assembly
JOIN Parts AS Parent ON Parent.part = Assemblies.parent

;

CREATE VIEW AssemblyParts ( assembly, parentName, assemblyName, assemblyVersion, assemblyVersionName, assemblySerial, quantity, designator, part, partName, version, versionName, serial ) AS

SELECT AssemblyPart.assembly, Parent.name AS parentName,
 Assemblies.name AS assemblyName,
 Assemblies.versionid AS assemblyVersion, Assemblies.version AS assemblyVersionName,
 Assemblies.serial AS assemblySerial,
 AssemblyPart.quantity,
 Designator.value AS designator,
 Parts.part, Parts.name AS partName,
 Parts.versionid AS version, Parts.version AS versionName,
 Parts.serial
FROM AssemblyPart
JOIN Parts AS Assemblies ON Assemblies.part = AssemblyPart.assembly
JOIN Parts AS Parent ON Parent.part = Assemblies.parent
JOIN Parts AS Parts ON parts.part = AssemblyPart.part
LEFT JOIN I18NWord AS Designator ON Designator.id = AssemblyPart.designator

;

CREATE VIEW AssemblyApplicationReleases ( assemblyapplicationrelease, applicationrelease, assembly, application, release, assemblyparent, assemblyname, assemblyverionid, assemblyversion, serial, applicationid, applicationname, goesby, applicationpath, applicationversionid, applicationversionname, buildname, created ) AS

   SELECT AssemblyApplicationRelease.id AS assemblyApplicationRelease,
    AssemblyApplicationRelease.applicationRelease,
    Assembly.part AS assembly,
    ApplicationReleases.application,
    ApplicationReleases.release,
    Assembly.parent AS assemblyParent,
    Assembly.name AS assemblyName,
    Assembly.versionId AS assemblyVerionId,
    Assembly.version AS assemblyVersion,
    Assembly.serial,
    ApplicationReleases.application AS applicationId,
    ApplicationReleases.name AS applicationName,
    ApplicationReleases.goesBy,
    ApplicationReleases.applicationPath,
    ApplicationReleases.versionId AS applicationVersionId,
    ApplicationReleases.versionName AS applicationVersionName,
    ApplicationReleases.buildName,
    AssemblyApplicationRelease.created
   FROM AssemblyApplicationRelease
   JOIN Parts AS Assembly ON Assembly.part = AssemblyApplicationRelease.assembly
   JOIN ApplicationReleases ON ApplicationReleases.applicationrelease = AssemblyApplicationRelease.applicationrelease

;

CREATE VIEW Periods ( period, name, periodname ) AS

SELECT PeriodName.period, PeriodName.name, I18NSentence.value AS periodName
FROM PeriodName
LEFT JOIN I18NSentence ON I18NSentence.id = PeriodName.name

;

CREATE VIEW PeriodSpans ( period, name, periodname, span, exclude, monthdaymonth, day, weekofmonth, dayofweekstart, dayofweekstop, dayofmonth, month, monthyear, daterangestart, daterangestop, timeofdaystart, timeofdaystop ) AS

SELECT PeriodName.period, PeriodName.name, I18NSentence.value AS periodName,
 Period.span, Period.exclude,
 MonthDay.month AS MonthDaymonth, MonthDay.day, MonthDay.weekOfMonth,
 DayOfWeek.start AS dayOfWeekStart, DayOfWeek.stop AS dayOfWeekStop, DayOfWeek.dayOfMonth,
 Month.month, Month.year AS monthYear,
 DateRange.start AS dateRangeStart, DateRange.stop AS dateRangeStop,
 TimeOfDay.start AS timeOfDayStart, TimeOfDay.stop AS timeOfDayStop
FROM Period
JOIN PeriodName ON PeriodName.period = Period.id
JOIN I18NSentence ON I18NSentence.id = PeriodName.name
LEFT JOIN MonthDay  ON MonthDay.id  = Period.span
LEFT JOIN DayOfWeek ON DayOfWeek.id = Period.span
LEFT JOIN Month     ON Month.id     = Period.span
LEFT JOIN DateRange ON DateRange.id = Period.span
LEFT JOIN TimeOfDay ON TimeOfDay.id = Period.span

;

CREATE VIEW TimePeriod ( period, open ) AS

SELECT period, bool_AND(open) AS open
FROM (
SELECT Period.id AS period,
 CAST(ClientNow() AS date) > make_date(CAST(extract(year FROM ClientNow()) AS integer),MonthDay.month, MonthDay.day) -1 AND
 CAST(ClientNow() AS date) <= make_date(CAST(extract(year FROM ClientNow()) AS integer),MonthDay.month, MonthDay.day) AS open
FROM Period
JOIN MonthDay ON MonthDay.id = Period.span
 AND MonthDay.weekOfMonth IS NULL
UNION
SELECT Period.id AS period,
 Month.month = extract(month FROM ClientNow())
FROM Period
JOIN Month ON Month.id = Period.span
 AND Month.year IS NULL
UNION
SELECT Period.id AS period,
 CAST(ClientNow() AS date) = (
  make_date(CAST(extract(year FROM ClientNow()) AS integer),CAST(extract(month FROM ClientNow()) AS integer), 1) + 7 * (DayOfWeek.start - 1) +
  CAST((7 + DayOfWeek.dayOfMonth - (dayofweek(
    make_date(CAST(extract(year FROM ClientNow()) AS integer),CAST(extract(month FROM ClientNow()) AS integer), 1) + 7 * (DayOfWeek.start - 1)
   ) -1)
  ) AS integer) %7
 )
FROM Period
JOIN DayOfWeek ON DayOfWeek.id = Period.span
 AND DayOfWeek.stop IS NULL
 AND DayOfWeek.dayOfMonth > 0
UNION
SELECT Period.id AS period,
 CAST(ClientNow() AS time) >= start
  AND CAST(ClientNow() AS time) < stop
FROM Period
JOIN TimeOfDay ON TimeOfDay.id = Period.span
 AND TimeOfDay.start < TimeOfDay.stop
UNION
SELECT Period.id AS period,
 (CAST(ClientNow() AS time) >= start
   AND CAST(ClientNow() AS time) <= '23:59:59'
 ) OR (
  CAST(ClientNow() AS time) < stop
   AND CAST(ClientNow() AS time) >= '00:00:00'
 )
FROM Period
JOIN TimeOfDay ON TimeOfDay.id = Period.span
 AND TimeOfDay.start > TimeOfDay.stop
) AS TimePeriod
GROUP BY period

;

CREATE VIEW MaxSpan ( id ) AS

SELECT MAX(id) AS id FROM (
 SELECT coalesce(MAX(id), 0) AS id FROM DateRange
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM TimeOfDay
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM DayOfWeek
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM MonthDay
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM Month
) AS MaxSpan

;

CREATE VIEW Accounts ( account, name, type, typeName, individual, individualName, individualAccountType, individualAccountTypeName, credit, debitIncrease, debitDecrease, creditIncrease, creditDecrease ) AS

SELECT AccountName.account,
 I18NSentence.value AS name,
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
JOIN I18NSentence ON I18NSentence.id = AccountName.name
JOIN I18NWord AS TypeName ON TypeName.id = AccountName.type
LEFT JOIN IndividualAccount ON IndividualAccount.account = AccountName.account
 AND IndividualAccount.stop IS NULL
LEFT JOIN People ON People.individual = IndividualAccount.individual
LEFT JOIN Entities ON Entities.individual = IndividualAccount.individual
LEFT JOIN I18NWord AS IndividualAccountType ON IndividualAccountType.id = IndividualAccount.type

;

CREATE VIEW Ledgers ( ledger, name, sequence, account, accountname, type, typename, credit, debitincrease, debitdecrease, creditincrease, creditdecrease ) AS

SELECT LedgerName.ledger,
 I18NSentence.value AS name,
 LedgerAccount.sequence,
 Accounts.account,
 Accounts.name AS accountName,
 Accounts.type,
 Accounts.typeName,
 Accounts.credit,
 Accounts.debitIncrease,
 Accounts.debitDecrease,
 Accounts.creditIncrease,
 Accounts.creditDecrease
FROM LedgerName
JOIN I18NSentence ON I18NSentence.id = LedgerName.name
JOIN LedgerAccount ON LedgerAccount.ledger = LedgerName.ledger
JOIN Accounts ON Accounts.account = LedgerAccount.account

;

CREATE VIEW Journals ( journal, name ) AS

SELECT JournalName.journal,
 I18NSentence.value AS name
FROM JournalName
JOIN I18NSentence ON I18NSentence.id = JournalName.name

;

CREATE VIEW Books ( book, name, journal, journalname, split, increase, increasename, increasetype, increasecredit, increasedebitincrease, increasedebitdecrease, increasecreditincrease, increasecreditdecrease, decrease, decreasename, decreasetype, decreasecredit, decreasedebitincrease, decreasedebitdecrease, decreasecreditincrease, decreasecreditdecrease ) AS

SELECT BookName.book,
 I18NSentence.value AS name,
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
JOIN I18NSentence ON I18NSentence.id = BookName.name
JOIN Journals ON Journals.journal = BookName.journal
JOIN BookAccount ON BookAccount.book = BookName.book
LEFT JOIN Accounts AS Increase ON Increase.account = BookAccount.increase
LEFT JOIN Accounts AS Decrease  ON Decrease.account  = BookAccount.decrease

;

CREATE VIEW JournalEntries ( id, journal, journalname, book, bookname, entry, account, accountname, type, typename, ledger, ledgername, rightside, debit, credit, posted, created ) AS

SELECT JournalEntry.id,
 JournalEntry.journal,
 JournalNameString.value AS journalName,
 JournalEntry.book,
 BookNameString.value AS bookName,
 JournalEntry.entry,
 JournalEntry.account,
 AccountNameString.value AS accountName,
 AccountName.type,
 AccountTypeName.value AS typeName,
 LedgerJournal.ledger,
 LedgerNameString.value AS ledgerName,
 JournalEntry.credit AS rightSide,
 CASE WHEN NOT JournalEntry.credit THEN
  JournalEntry.amount
 END AS debit,
 CASE WHEN JournalEntry.credit THEN
  JournalEntry.amount
 END AS credit,
 JournalEntry.posted,
 JournalEntry.created
FROM JournalEntry
JOIN AccountName ON AccountName.account = JournalEntry.account
JOIN I18NSentence AS AccountNameString ON AccountNameString.id = AccountName.name
JOIN I18NWord AS AccountTypeName ON AccountTypeName.id = AccountName.type
JOIN JournalName ON JournalName.journal = JournalEntry.journal
JOIN I18NSentence AS JournalNameString ON JournalNameString.id = JournalName.name
LEFT JOIN BookName ON BookName.book = JournalEntry.book
LEFT JOIN I18NSentence AS BookNameString ON BookNameString.id = BookName.name
LEFT JOIN LedgerJournal ON LedgerJournal.journal = JournalEntry.journal
LEFT JOIN LedgerName ON LedgerName.ledger = LedgerJournal.ledger
LEFT JOIN I18NSentence AS LedgerNameString ON LedgerNameString.id = LedgerName.name

;

CREATE VIEW LedgerBalance ( ledger, ledgername, sequence, account, accountname, type, typename, debit, credit ) AS

SELECT Ledgers.ledger,
 Ledgers.name AS ledgerName,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName,
 SUM(JournalEntries.debit) AS debit,
 SUM(JournalEntries.credit) AS credit
FROM JournalEntries
JOIN Ledgers ON Ledgers.ledger = JournalEntries.ledger
 AND Ledgers.type = JournalEntries.type
WHERE JournalEntries.posted IS NULL
GROUP BY Ledgers.ledger,
 Ledgers.name,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName

;

CREATE VIEW JournalReport ( journal, journalName, entry, account, type, ledger, ledgerName, debit, credit, rightside, created ) AS

SELECT journal,
 journalName,
 entry,
 accountName AS account,
 typeName AS type,
 ledger,
 ledgerName,
 debit,
 credit,
 rightSide,
 created
FROM JournalEntries
WHERE posted IS NULL
UNION ALL
SELECT NULL AS journal,
 NULL AS journalName,
 NULL AS entry,
 'Total' AS account,
 NULL AS type,
 MAX(ledger) AS ledger,
 MAX(ledgerName) AS ledgerName,
 SUM(debit) AS debit,
 SUM(credit) AS credit,
 NULL AS rightSide,
 NULL AS created
FROM JournalEntries
WHERE posted IS NULL

;

CREATE VIEW LedgerReport ( ledger, sequence, ledgername, accountname, typename, debit, credit ) AS

SELECT ledger,
 sequence,
 ledgername,
 accountname,
 typename,
 debit,
 credit
FROM LedgerBalance
UNION ALL
SELECT ledger,
 NULL AS sequence,
 ledgerName,
 'Total' AS accountName,
 NULL AS typeName,
 SUM(debit) AS debit,
 SUM(credit) AS credit
FROM LedgerBalance
GROUP BY ledger,
 ledgerName

;

CREATE VIEW Edges ( edge, startName, stopName, hops, entry, direct, exit, start, stop ) AS

SELECT Edge.id AS edge,
 StartVertexNameString.value AS startName,
 StopVertexNameString.value AS stopName,
 hops,
 entry,
 direct,
 exit,
 start,
 stop
FROM Edge
JOIN VertexName AS StartVertexName ON StartVertexName.vertex = Edge.start
JOIN I18NSentence AS StartVertexNameString ON StartVertexNameString.id = StartVertexName.name
JOIN VertexName AS StopVertexName ON StopVertexName.vertex = Edge.stop
LEFT JOIN I18NSentence AS StopVertexNameString ON StopVertexNameString.id = StopVertexName.name

;

CREATE VIEW EdgeIndividuals ( edge, startname, stopname, startindividual, startindividualname, starttype, stopindividual, stopindividualname, stoptype, hops, entry, direct, exit ) AS

SELECT Edge.id AS edge,
 StartVertexNameString.value AS startName,
 StopVertexNameString.value AS stopName,
 StartIndividualVertex.individual AS startIndividual,
 StartType.value AS startType,
 COALESCE(StartPeople.fullname, StartEntities.name) AS startIndividualName,
 StopIndividualVertex.individual AS stopIndividual,
 COALESCE(StopPeople.fullname, StopEntities.name) AS stopIndividualName,
 StopType.value AS stopType,
 hops,
 entry,
 direct,
 exit,
 start,
 Edge.stop
FROM Edge
JOIN VertexName AS StartVertexName ON StartVertexName.vertex = Edge.start
JOIN VertexName AS StopVertexName ON StopVertexName.vertex = Edge.stop
LEFT JOIN I18NSentence AS StartVertexNameString ON StartVertexNameString.id = StartVertexName.name
LEFT JOIN I18NSentence AS StopVertexNameString ON StopVertexNameString.id = StopVertexName.name
LEFT JOIN IndividualVertex AS StartIndividualVertex ON StartIndividualVertex.vertex = Edge.start
LEFT JOIN People AS StartPeople ON StartPeople.individual = StartIndividualVertex.individual
LEFT JOIN Entities AS StartEntities ON StartEntities.individual = StartIndividualVertex.individual
LEFT JOIN Word AS StartType ON StartType.id = StartIndividualVertex.type
 AND StartType.culture IS NULL
LEFT JOIN IndividualVertex AS StopIndividualVertex ON StopIndividualVertex.vertex = Edge.stop
LEFT JOIN People AS StopPeople ON StopPeople.individual = StopIndividualVertex.individual
LEFT JOIN Entities AS StopEntities ON StopEntities.individual = StopIndividualVertex.individual
LEFT JOIN Word AS StopType ON StopType.id = StopIndividualVertex.type
 AND StopType.culture IS NULL

;

CREATE VIEW AssemblyCurrentPrice ( assembly, nameid, supplier, price, created ) AS

SELECT Part.id AS assembly,
 Part.name AS nameId,
 IndividualAssemblyCustomerPrice.individual AS supplier,
 IndividualAssemblyCustomerPrice.price,
 IndividualAssemblyCustomerPrice.created
FROM Part
JOIN IndividualAssemblyCustomerPrice ON IndividualAssemblyCustomerPrice.assembly = Part.id
 AND IndividualAssemblyCustomerPrice.stop IS NULL
-- Default Prices, no specific supplier
UNION ALL
SELECT Part.id AS assembly,
 Part.name AS nameId,
 NULL AS supplier,
 MAX(IndividualAssemblyCustomerPrice.price) AS price,
 MAX(IndividualAssemblyCustomerPrice.created) AS created
FROM Part
LEFT JOIN IndividualAssemblyCustomerPrice ON IndividualAssemblyCustomerPrice.assembly = Part.id
 AND IndividualAssemblyCustomerPrice.stop IS NULL
GROUP BY Part.id,
 Part.name

;

CREATE VIEW Bills ( bill, type, date, supplier, supplierName, consignee, consigneeName, source, sourceType, parent, parentType ) AS

SELECT
 Bill.id AS bill,
 Type.value AS type,
 DATE(Bill.created) AS date,
 Bill.supplier,
 Supplier.name AS supplierName,
 Bill.consignee,
 Consignee.name AS consigneeName,
 Source.id AS source,
 SourceType.value AS sourceType,
 Parent.id AS parent,
 ParentType.value AS parentType
FROM Bill
JOIN I18NWord AS Type ON Type.id = Bill.type
JOIN Entities AS Supplier ON Supplier.individual = Bill.supplier
JOIN Entities AS Consignee ON Consignee.individual = Bill.consignee
LEFT JOIN Bill AS Source ON Source.id = Bill.source
LEFT JOIN I18NWord AS SourceType ON SourceType.id = Source.type
LEFT JOIN Bill AS Parent ON Parent.id = Bill.parent
LEFT JOIN I18NWord AS ParentType ON ParentType.id = Parent.type

;

CREATE VIEW CargoesRaw ( bill, source, parent, type, supplier, consignee, created, cargo, count, individualjob, assembly, journal, entry ) AS

SELECT Bill.id AS bill,
 Bill.source,
 Bill.parent,
 Bill.type,
 Bill.supplier,
 Bill.consignee,
 Bill.created,
 Cargo.id AS cargo,
 COALESCE(Cargo.count, 1) AS count,
 Cargo.individualJob,
 Cargo.assembly,
 Cargo.journal,
 Cargo.entry
FROM Bill
JOIN Cargo ON Cargo.bill = Bill.id

;

CREATE VIEW Cargoes ( bill, type, supplier, consignee, created, cargo, count, individualJob, assembly, journal, entry ) AS

SELECT bill,
 type,
 supplier,
 consignee,
 created,
 cargo,
 SUM(COALESCE(count, 1)) AS count,
 individualJob,
 assembly,
 journal,
 entry
FROM CargoesRaw
GROUP BY bill,
 type,
 supplier,
 consignee,
 created,
 cargo,
 individualJob,
 assembly,
 journal,
 entry

;

CREATE VIEW LineItemsRaw ( bill, billsource, billparent, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, version, parent, currentunitprice, unitprice, individualjob, job, schedule ) AS

SELECT CargoesRaw.bill,
 CargoesRaw.source AS billSource,
 CargoesRaw.parent AS billParent,
 Type.value AS typeName,
 CargoesRaw.type,
 COALESCE(Supplier.goesBy, Supplier.name) AS supplierName,
 CargoesRaw.supplier,
 COALESCE(Consignee.goesBy, Consignee.name) AS consigneeName,
 CargoesRaw.consignee,
 CargoesRaw.count,
 CargoesRaw.cargo AS line,
 Parts.name AS item,
 Parts.part,
 Parts.version,
 Parts.parent,
 COALESCE(SpecificPrice.price, DefaultPrice.price, AssemblyIndividualJobPrice.price) AS currentUnitPrice,
 COALESCE(JournalEntry.amount / CargoesRaw.count, FixedAssemblyIndividualJobPrice.price) AS unitPrice,
 IndividualJob.id AS individualJob,
 IndividualJob.job,
 IndividualJob.schedule
FROM CargoesRaw
JOIN I18NWord AS Type ON Type.id = CargoesRaw.type
JOIN Entities AS Supplier ON Supplier.individual = CargoesRaw.supplier
JOIN Entities AS Consignee ON Consignee.individual = CargoesRaw.consignee
JOIN Parts ON Parts.part = CargoesRaw.assembly
JOIN AssemblyCurrentPrice AS DefaultPrice ON DefaultPrice.assembly = CargoesRaw.assembly
 AND DefaultPrice.supplier IS NULL
LEFT JOIN AssemblyCurrentPrice AS SpecificPrice ON SpecificPrice.assembly = CargoesRaw.assembly
 AND SpecificPrice.supplier = CargoesRaw.supplier
LEFT JOIN JournalEntry ON JournalEntry.journal = CargoesRaw.journal
 AND JournalEntry.entry = CargoesRaw.entry
 AND JournalEntry.credit -- Income to bill.supplier
LEFT JOIN IndividualJob ON IndividualJob.individual = CargoesRaw.consignee
 AND IndividualJob.stop IS NULL
LEFT JOIN AssemblyIndividualJobPrice ON AssemblyIndividualJobPrice.assembly = CargoesRaw.assembly
 AND AssemblyIndividualJobPrice.individualJob = IndividualJob.id
LEFT JOIN IndividualJob AS FixedIndividualJob ON FixedIndividualJob.id = CargoesRaw.individualJob
LEFT JOIN AssemblyIndividualJobPrice AS FixedAssemblyIndividualJobPrice ON FixedAssemblyIndividualJobPrice.assembly = CargoesRaw.assembly
 AND FixedAssemblyIndividualJobPrice.individualJob =  FixedIndividualJob.id

;

CREATE VIEW LineItems ( bill, billsource, billparent, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, version, parent, currentUnitPrice, unitprice, totalPrice, outstanding, individualjob, job, schedule ) AS

SELECT bill,
 billsource,
 billparent,
 typeName,
 type,
 supplierName,
 supplier,
 consigneeName,
 consignee,
 SUM(LineItemsRaw.count) AS count,
 line,
 item,
 part,
 version,
 parent,
 currentUnitPrice,
 unitPrice,
 SUM(LineItemsRaw.count) * unitPrice AS totalPrice,
 CASE WHEN CargoStateSum.cargo IS NOT NULL THEN
  SUM(LineItemsRaw.count) - CargoStateSum.count
 ELSE
  SUM(LineItemsRaw.count)
 END AS outstanding,
 individualJob,
 job,
 schedule
FROM LineItemsRaw
LEFT JOIN (
 SELECT cargo, SUM(COALESCE(count, 1)) AS count
 FROM CargoState
 GROUP BY CargoState.cargo
) AS CargoStateSum ON CargoStateSum.cargo = line
GROUP BY
 bill,
 billsource,
 billparent,
 typeName,
 type,
 supplierName,
 supplier,
 consigneeName,
 consignee,
 line,
 item,
 part,
 version,
 parent,
 currentUnitPrice,
 unitPrice,
 individualJob,
 job,
 schedule,
 CargoStateSum.cargo,
 CargoStateSum.count

;

CREATE VIEW CAs ( id, parent, name, owner ) AS

SELECT CA.id,
CA.parent,
Entity.name,
COALESCE(Entities.name, People.fullname) AS owner
FROM CA
JOIN Entity ON Entity.id = CA.name
LEFT JOIN Entities ON Entities.individual = CA.owner
LEFT JOIN People ON People.individual = CA.owner

;

CREATE VIEW Certificates ( id, type, isca, ca, parent, start, days, stop, cn, serial ) AS

SELECT Certificate.id,
 Type.value AS type,
 (CACertificate.ca IS NOT NULL) AS isca,
 CAPolicy.ca,
 CA.parent,
 start,
 Certificate.days,
 Start + Certificate.days * INTERVAL '1 day' AS stop,
 cn,
 Certificate.serial
FROM Certificate
JOIN I18NWord AS Type ON Type.id = Certificate.type
JOIN CAPolicy ON CAPolicy.id = Certificate.CAPolicy
JOIN CA ON CA.id = CAPolicy.ca
LEFT JOIN CACertificate ON CACertificate.certificate = Certificate.id

;


-- 0.2.9: EST device bring-up write procedures (procedures.d/65-est.sql)
-- ---------------------------------------------------------------------------
-- EST / certificates (diagram: est)
-- Device bring-up helpers: public key, CSR, client certificate
-- Assembled in lexicographic order of this directory; see README.md

-- Soft-stop prior active keys for assembly, then append new PEM
CREATE OR REPLACE FUNCTION PutAssemblyPublicKey (
 inAssembly integer,
 inPem varchar
) RETURNS void AS $$
BEGIN
 IF inAssembly IS NULL OR inPem IS NULL THEN
  RETURN;
 END IF;

 UPDATE AssemblyPublicKey
 SET stop = NOW()
 WHERE assembly = inAssembly
  AND stop IS NULL;

 INSERT INTO AssemblyPublicKey (assembly, pem)
 VALUES (inAssembly, inPem);
END;
$$ LANGUAGE plpgsql;

-- Insert CSR; return id
CREATE OR REPLACE FUNCTION PutCertificateSigningRequest (
 inPem varchar,
 inIndividual bigint
) RETURNS integer AS $$
DECLARE
 csr_id integer;
BEGIN
 IF inPem IS NULL THEN
  RETURN NULL;
 END IF;

 INSERT INTO CertificateSigningRequest (pem, individual)
 VALUES (inPem, inIndividual)
 RETURNING id INTO csr_id;

 RETURN csr_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION PutCertificateSigningRequest (
 inPem varchar,
 inIndividual bigint,
 inSession bigint
) RETURNS integer AS $$
DECLARE
 csr_id integer;
BEGIN
 IF inPem IS NULL THEN
  RETURN NULL;
 END IF;

 INSERT INTO CertificateSigningRequest (pem, individual, session)
 VALUES (inPem, inIndividual, inSession)
 RETURNING id INTO csr_id;

 RETURN csr_id;
END;
$$ LANGUAGE plpgsql;

-- Soft-stop prior active assembly–CSR links, then link assembly to CSR
CREATE OR REPLACE FUNCTION PutAssemblyCertificateSigningRequest (
 inAssembly integer,
 inCsr integer
) RETURNS void AS $$
BEGIN
 IF inAssembly IS NULL OR inCsr IS NULL THEN
  RETURN;
 END IF;

 UPDATE AssemblyCertificateSigningRequest
 SET stop = NOW()
 WHERE assembly = inAssembly
  AND stop IS NULL;

 INSERT INTO AssemblyCertificateSigningRequest (assembly, csr)
 VALUES (inAssembly, inCsr);
END;
$$ LANGUAGE plpgsql;

-- Client (or other) certificate row; type is a Word value (e.g. 'Client')
-- inDays is integer for easier call-site resolution (stored as Certificate.days smallint)
CREATE OR REPLACE FUNCTION PutCertificate (
 inCaPolicy integer,
 inType varchar,
 inIndividual bigint,
 inCsr integer,
 inStart timestamp,
 inDays integer,
 inO varchar,
 inOu varchar,
 inCn varchar,
 inEmail integer,
 inSerial varchar,
 inPem varchar
) RETURNS integer AS $$
DECLARE
 cert_id integer;
 type_id integer;
BEGIN
 IF inCaPolicy IS NULL OR inPem IS NULL THEN
  RETURN NULL;
 END IF;

 type_id := GetWord(inType);

 INSERT INTO Certificate (
  caPolicy,
  type,
  individual,
  csr,
  start,
  days,
  o,
  ou,
  cn,
  email,
  serial,
  pem
 ) VALUES (
  inCaPolicy,
  type_id,
  inIndividual,
  inCsr,
  inStart,
  inDays::smallint,
  inO,
  inOu,
  inCn,
  inEmail,
  inSerial,
  inPem
 )
 RETURNING id INTO cert_id;

 RETURN cert_id;
END;
$$ LANGUAGE plpgsql;

-- Mark schema upgraded to 0.2.9
SELECT SetSchemaVersion('Business', '0', '2', '9');
