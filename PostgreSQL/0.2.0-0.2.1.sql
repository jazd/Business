-- Update From Schema Release 0.2.0 to 0.2.1
--
-- Return BigInt Individual.id
-- Update IndividualEmail.stop
-- GetSentence
-- GetIndividualEntity(<Entity Name>)
-- cargo_id_seq
-- AddCargo() root function
-- GetPostal return value did not work with Location lat/log incorrect types
--  Postal entries from Static/GeoNamesUSZipSample.tsv will need to be fixed by hand in existing databases
-- CreateBill with parent
-- AddCargo that updates CargoState
-- MoveCargo that uses CargoState
-- MoveCargoToChild
-- GetSchedule
-- GetJob
-- GetIndividualJobSchedule


DROP TABLE IF EXISTS JobIndividual;
--
-- Table: IndividualJob
--
DROP TABLE IF EXISTS IndividualJob CASCADE;
CREATE TABLE IndividualJob (
  -- Not unique.  Used to group one or more individuals and/or schedules together for a single corgo record
  id integer NOT NULL,
  -- NULL if a service fee
  individual bigint,
  job integer NOT NULL,
  schedule integer,
  -- NULL if schedule shown in detail, otherwise group together under this name
  aggregate integer,
  -- No longer associate this record with job.  Used instead of DELETE.
  stop timestamp,
  created timestamp DEFAULT now() NOT NULL
);
ALTER TABLE IndividualJob ADD CONSTRAINT individualjob_job FOREIGN KEY (job)
  REFERENCES JobName (job) DEFERRABLE;

--
-- Table: AssemblyIndividualJobPrice
--
CREATE TABLE AssemblyIndividualJobPrice (
  assembly integer,
  individualJob integer NOT NULL,
  price float NOT NULL,
  created timestamp DEFAULT now() NOT NULL
);
ALTER TABLE AssemblyIndividualJobPrice ADD CONSTRAINT assemblyschedule_assembly FOREIGN KEY (assembly)
  REFERENCES Part (id) DEFERRABLE;



--
-- Table: Cargo
--
DROP TABLE IF EXISTS Cargo CASCADE;
CREATE TABLE Cargo (
  -- Not unique. Cargo lines can be adjusted before Bill.clean or Bill.dirty
  id integer NOT NULL,
  bill integer NOT NULL,
  -- NULL is count 1
  count float,
  -- NULL if Job
  assembly integer,
  -- NULL if Assembly
  individualJob integer,
  journal integer,
  -- Item.amount and Item.cost like fields come from JournalEntry records.Line item total is count x amount. JournalEntry.amount Overrides IndividualAssemblyCustomerPrice.price or IndividualJob.schedule.Line item total cost. JournalEntry.amount Overrides IndividualAssemblyCost or IndividualJob.schedule
  entry integer,
  created timestamp DEFAULT now() NOT NULL
);
ALTER TABLE Cargo ADD CONSTRAINT cargo_bill FOREIGN KEY (bill)
  REFERENCES Bill (id) DEFERRABLE;

ALTER TABLE Cargo ADD CONSTRAINT cargo_assembly FOREIGN KEY (assembly)
  REFERENCES Part (id) DEFERRABLE;

ALTER TABLE CargoState ADD CONSTRAINT cargostate_entry FOREIGN KEY (entry)
  REFERENCES Entry (id) DEFERRABLE;

CREATE OR REPLACE FUNCTION GetSentence (
 sentence_value varchar,
 culture_name varchar
) RETURNS integer AS $$
DECLARE
BEGIN
 IF sentence_value IS NOT NULL THEN
  INSERT INTO Sentence (value, culture, length) (
   SELECT sentence_value, Culture.code, LENGTH(sentence_value)
   FROM Culture
   LEFT JOIN Sentence AS exists ON UPPER(exists.value) = UPPER(sentence_value)
    AND exists.culture = Culture.code
   WHERE UPPER(Culture.name) = UPPER(culture_name)
    AND exists.id IS NULL
   LIMIT 1
  );
 END IF;
 RETURN (
  SELECT id
  FROM Sentence
  JOIN Culture ON UPPER(Culture.name) = UPPER(culture_name)
  WHERE UPPER(Sentence.value) = UPPER(sentence_value)
   AND Sentence.culture = Culture.code
  LIMIT 1
 );
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
 book_amount float;
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
IF inToBill IS NOT NULL THEN
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
DECLARE scheduleName_id integer;
DECLARE schedule_id integer;
BEGIN
 IF inScheduleName IS NOT NULL THEN
   scheduleName_id := GetSentence(inScheduleName);
   INSERT INTO ScheduleName (name) (
    SELECT scheduleName_id
    FROM DUAL
    LEFT JOIN ScheduleName AS exists ON exists.name = scheduleName_id
    WHERE exists.schedule IS NULL
    LIMIT 1
   ) RETURNING schedule INTO schedule_id;
   IF schedule_id IS NULL THEN
    schedule_id = (
     SELECT schedule
     FROM ScheduleName
     WHERE name = scheduleName_id
     LIMIT 1
    );
   END IF;
 END IF;
 RETURN schedule_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetJob (
 inJobName varchar
) RETURNS integer AS $$
DECLARE jobName_id integer;
DECLARE job_id integer;
BEGIN
 IF inJobName IS NOT NULL THEN
  jobName_id := GetSentence(inJobName);
  INSERT INTO JobName (name) (
   SELECT jobName_id
   FROM DUAL
   LEFT JOIN JobName AS exists ON exists.name = jobName_id
   WHERE exists.job IS NULL
   LIMIT 1
  ) RETURNING job INTO job_id;
  IF job_id IS NULL THEN
   job_id = (
    SELECT job
    FROM JobName
    WHERE name = jobName_id
    LIMIT 1
   );
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


DROP FUNCTION IF EXISTS SetIndividualEmail(bigint,integer);
DROP FUNCTION IF EXISTS SetIndividualEmail(bigint,integer,character varying);
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

CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 individual_id bigint;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  individual_id := (
   SELECT id
   FROM Individual
   WHERE entity = entity_name_id
  );
  IF individual_id IS NULL THEN
   INSERT INTO Individual (entity) VALUES (entity_name_id) RETURNING id INTO individual_id;
  END IF;
 END IF;
 RETURN individual_id;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE cargo_id_seq START WITH 100;


DROP VIEW IF EXISTS ADDRESSES;
ALTER TABLE Location ALTER COLUMN latitude TYPE NUMERIC(10,7);
ALTER TABLE Location ALTER COLUMN longitude TYPE NUMERIC(11,7);

--
-- View: Addresses
--
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
JOIN I8NWord AS City ON City.id = Postal.city
JOIN I8NWord AS State ON State.id = Postal.state
LEFT JOIN I8NWord AS StateAbbr ON StateAbbr.id = Postal.stateAbbreviation
LEFT JOIN Location AS AddressLocation On AddressLocation.id = Address.location
LEFT JOIN Location AS PostalLocation ON PostalLocation.id = Postal.location
LEFT JOIN Location AS CountryLocation ON CountryLocation.id = Country.location
;

--
-- View: Cargoes
--
DROP VIEW IF EXISTS Cargoes CASCADE;
DROP VIEW IF EXISTS LineItems; -- Cascade should get this

--
-- View: CargoesRaw
--
CREATE OR REPLACE VIEW CargoesRaw ( bill, type, supplier, consignee, created, cargo, count, individualjob, assembly, journal, entry ) AS
SELECT Bill.id AS bill,
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

--
-- View: Cargoes
--
CREATE OR REPLACE VIEW Cargoes ( bill, type, supplier, consignee, created, cargo, count, individualJob, assembly, journal, entry ) AS
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

--
-- View: LineItemsRaw
--
CREATE OR REPLACE VIEW LineItemsRaw (bill, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, currentunitprice, totalprice, individualjob, job, schedule) AS
SELECT CargoesRaw.bill,
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
 COALESCE(SpecificPrice.price, DefaultPrice.price, AssemblyIndividualJobPrice.price) AS currentUnitPrice,
 COALESCE(JournalEntry.amount, FixedAssemblyIndividualJobPrice.price) AS totalPrice,
 IndividualJob.id AS individualJob,
 IndividualJob.job,
 IndividualJob.schedule
FROM CargoesRaw
JOIN I8NWord AS Type ON Type.id = CargoesRaw.type
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

--
-- View: LineItems
--
CREATE VIEW LineItems ( bill, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, currentUnitPrice, unitPrice, totalPrice, outstanding, individualjob, job, schedule ) AS
SELECT bill,
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
 currentUnitPrice,
 SUM(totalPrice) / SUM(LineItemsRaw.count) AS unitPrice,
 SUM(totalPrice) AS totalPrice,
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
 typeName,
 type,
 supplierName,
 supplier,
 consigneeName,
 consignee,
 line,
 item,
 part,
 currentUnitPrice,
 individualJob,
 job,
 schedule,
 CargoStateSum.cargo,
 CargoStateSum.count
;

--
-- View: JournalReport
--
DROP VIEW IF EXISTS JournalReport;
CREATE VIEW JournalReport ( journal, entry, account, type, ledger, ledgerName, debit, credit, rightside, created ) AS
SELECT journal,
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

--
-- View: AssemblyCurrentPrice
--
DROP VIEW IF EXISTS AssemblyCurrentPrice;
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

--
-- View: PeopleEvent
--
DROP VIEW IF EXISTS PeopleEvent;
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
 LEFT JOIN I8NWord AS Honorific ON Honorific.id = IndividualPersonEvent.honorific
 LEFT JOIN I8NWord AS Suffix ON Suffix.id = IndividualPersonEvent.suffix
 LEFT JOIN I8NWord AS Post ON Post.id = IndividualPersonEvent.post
 LEFT JOIN I8NWord AS Born ON Born.value = 'Born' AND birth = event
 LEFT JOIN I8NWord AS Death ON Death.value = 'Died' AND death = event
 LEFT JOIN I8NWord AS Change ON Change.value = 'Changed name'
;


CREATE OR REPLACE FUNCTION GetIndividualEntity (
 inName varchar,
 inFormed date,
 inGoesBy varchar,
 inDissolved date
) RETURNS bigint AS $$
DECLARE
 entity_name_id integer;
 goesBy_id integer;
BEGIN
 entity_name_id := (SELECT GetEntityName(inName));
 IF entity_name_id IS NOT NULL THEN
  goesBy_id := (SELECT GetGiven(inGoesBy));

  INSERT INTO Individual (entity, goesBy, birth, death)
  SELECT entity_name_id, goesBy_id, inFormed, inDissolved
  FROM DUAL
  LEFT JOIN Individual AS exists ON exists.entity = entity_name_id
  WHERE exists.id IS NULL
  LIMIT 1
  ;
 END IF;
 RETURN (
  SELECT id FROM Individual
  WHERE Individual.entity = entity_name_id
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPart (
 inName varchar,
 inVersion integer
) RETURNS integer AS $$
DECLARE name_id integer;
DECLARE sibling_id integer;
DECLARE parent_id integer;
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
 END IF;
 RETURN (
  SELECT id
  FROM Part
  WHERE name = name_id
   AND parent = parent_id
   AND version = inVersion
   AND serial IS NULL
  LIMIT 1
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GetPhone (
 inCountryCode varchar,
 inAreaCode varchar,
 inNumber varchar
) RETURNS integer AS $$
DECLARE
 countrycode_id integer;
BEGIN
 countrycode_id := (SELECT id FROM Country WHERE UPPER(Country.code) = UPPER(inCountryCode));
 IF countrycode_id IS NOT NULL THEN
  INSERT INTO Phone (country, area, number) (
   SELECT countrycode_id, inAreaCode, inNumber
   FROM Dual
   LEFT JOIN Phone AS exists ON exists.country = countrycode_id
    AND exists.area = inAreaCode
    AND exists.number = inNumber
   WHERE exists.id IS NULL
   LIMIT 1
 );
 END IF;
 RETURN (
  SELECT id
  FROM Phone
  WHERE country = countrycode_id
   AND area = inAreaCode
   AND number = inNumber
  LIMIT 1
 );
END;
$$ LANGUAGE plpgsql;

-- Drop functions thas use JournalEntryResult
DROP FUNCTION IF EXISTS Book(varchar, float);
--
DROP TYPE IF EXISTS JournalEntryResult;
CREATE TYPE JournalEntryResult AS (
 journal INTEGER,
 entry INTEGER
);

--
-- Book single amounts into double entry Journal
CREATE OR REPLACE FUNCTION Book (
 inBook varchar,
 inAmount FLOAT
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
 inAmount FLOAT
) RETURNS TABLE (
 book integer,
 entry integer,
 account integer,
 nameId integer,
 name varchar,
 rightside boolean,
 type integer,
 typeName varchar,
 debit float,
 credit float
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


-- New Static Records
-- 1_Sentence.sql
INSERT INTO Sentence (id,culture,value,length) VALUES (212,1033,'AR Sale',7);
INSERT INTO Sentence (id,culture,value,length) VALUES (213,1033,'AR Sale Credit',14);
INSERT INTO Sentence (id,culture,value,length) VALUES (214,1033,'AR Payment',10);
-- 5_GeneralLedger.sql
INSERT INTO BookName (book, name, journal) VALUES (13, 212, 2); -- AR Sale, Sales
INSERT INTO BookName (book, name, journal) VALUES (14, 213, 2); -- AR Sale Credit, Sales
INSERT INTO BookName (book, name, journal) VALUES (15, 214, 2); -- AR Sale Payment, Sales
--
INSERT INTO BookAccount (book, increase, decrease) VALUES (13, 108, 102);-- AR Sale: Receivable, Sales
INSERT INTO BookAccount (book, increase, decrease) VALUES (14, 102, 108);-- AR Sale Credit: Sales, Receivable
INSERT INTO BookAccount (book, increase, decrease) VALUES (15, 100, 108);-- AR Payment: Cash, Receivable


-- New build of Business 0.2.1
SELECT SetSchemaVersion('Business', '0', '2', '1');
