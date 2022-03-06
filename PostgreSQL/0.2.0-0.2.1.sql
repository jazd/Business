-- Update From Schema Release 0.2.0 to 0.2.1
--
-- Return BigInt Individual.id
-- Update IndividualEmail.stop
-- GetIndividualEntity(<Entity Name>)
-- cargo_id_seq
-- AddCargo() root function
-- GetPostal return value did not work with Location lat/log incorrect types
--  Postal entries from Static/GeoNamesUSZipSample.tsv will need to be fixed by hand in existing databases
-- CreateBill with parent
-- AddCargo that updates CargoState
-- MoveCargo that uses CargoState
-- MoveCargoToChild

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

DROP FUNCTION AddCargo(integer,integer,float,integer,integer,integer,integer);
CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inIndividualJob integer,
 inJournal integer,
 inEntry integer,
 inFromCargo integer
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
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

 IF inFromCargo IS NOT NULL THEN
  -- Create Cargo State records
  INSERT INTO CargoState (cargo, toCargo, count, journal, entry)
  VALUES (inFromCargo, cargo_id, inCount, inJournal, inEntry);
 END IF;

 RETURN cargo_id;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION AddCargo(integer,integer,float,integer,integer,integer);
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

CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float
) RETURNS integer AS $$
DECLARE
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
  Cargo.individualJob,
  Cargo.journal,
  Cargo.entry,
  Cargo.id)
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
  Cargo.individualJob,
  Cargo.journal,
  Cargo.entry,
  Cargo.id)
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

RETURN inToBill;

END;
$$ LANGUAGE plpgsql;



DROP FUNCTION SetIndividualEmail(bigint,integer);
DROP FUNCTION SetIndividualEmail(bigint,integer,character varying);
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

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inJobIndividual integer,
 inJournal integer,
 inEntry integer
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
BEGIN
 SELECT INTO cargo_id
  id AS cargo_id
 FROM Cargo
 WHERE bill = inBill
  AND assembly = inAssembly
  AND ((jobIndividual = inJobIndividual) OR (inJobIndividual IS NULL AND jobIndividual IS NULL))
  AND ((journal = inJournal) OR (inJournal IS NULL AND journal IS NULL))
  AND ((entry = inEntry) OR (inEntry IS NULL AND entry IS NULL))
 ORDER BY id DESC
 LIMIT 1
 ;

 IF cargo_id IS NULL THEN
  INSERT INTO Cargo (id, bill, count, assembly, jobIndividual, journal, entry)
  SELECT nextval('cargo_id_seq'),
   inBill,
   CASE WHEN inCount = 1 THEN
    NULL -- cargo record itself is a count of one unless overridden
   ELSE
    inCount
   END AS count,
   inAssembly,
   inJobIndividual,
   inJournal,
   inEntry
  FROM DUAL
  RETURNING id INTO cargo_id;
 ELSE
  INSERT INTO Cargo (id, bill, count, assembly, jobIndividual, journal, entry)
  SELECT cargo_id,
   inBill,
   inCount,
   inAssembly,
   inJobIndividual,
   inJournal,
   inEntry
  FROM DUAL
  ;
 END IF;

 RETURN cargo_id;
END;
$$ LANGUAGE plpgsql;


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
-- View: LineItems
--
DROP VIEW IF EXISTS LineItems;
CREATE VIEW LineItems ( bill, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, currentUnitPrice, unitPrice, totalPrice, outstanding ) AS
SELECT Cargoes.bill,
 Type.value AS typeName,
 Cargoes.type,
 COALESCE(Supplier.goesBy, Supplier.name) AS SupplierName,
 Cargoes.supplier,
 COALESCE(Consignee.goesBy, Consignee.name) AS ConsigneeName,
 Cargoes.consignee,
 Cargoes.count,
 Cargoes.cargo AS line,
 Parts.name AS item,
 Parts.part,
 COALESCE(SpecificPrice.price, DefaultPrice.price) AS currentUnitPrice,
 SUM(JournalEntry.amount) / Cargoes.count AS unitPrice,
 SUM(JournalEntry.amount) AS totalPrice,
 CASE WHEN CargoState.cargo IS NOT NULL THEN
  Cargoes.count - SUM(COALESCE(CargoState.count, 1))
 ELSE
  Cargoes.count
 END AS outstanding
FROM Cargoes
JOIN I8NWord AS Type ON Type.id = Cargoes.type
JOIN Entities AS Supplier ON Supplier.individual = Cargoes.supplier
JOIN Entities AS Consignee ON Consignee.individual = Cargoes.consignee
JOIN Parts ON Parts.part = Cargoes.assembly
JOIN AssemblyCurrentPrice AS DefaultPrice ON DefaultPrice.assembly = Cargoes.assembly
 AND DefaultPrice.supplier IS NULL
LEFT JOIN AssemblyCurrentPrice AS SpecificPrice ON SpecificPrice.assembly = Cargoes.assembly
 AND SpecificPrice.supplier = Cargoes.supplier
LEFT JOIN JournalEntry ON JournalEntry.journal = Cargoes.journal
 AND JournalEntry.entry = Cargoes.entry
 AND JournalEntry.credit -- Income to bill.supplier
LEFT JOIN CargoState ON CargoState.cargo = Cargoes.cargo
GROUP BY
 Cargoes.bill,
 Cargoes.type,
 Type.value,
 Supplier.goesBy,
 Supplier.name,
 Consignee.goesBy,
 Consignee.name,
 Cargoes.consignee,
 Cargoes.count,
 Cargoes.cargo,
 Cargoes.supplier,
 Cargoes.consignee,
 Cargoes.assembly,
 Parts.name,
 Parts.part,
 DefaultPrice.price,
 SpecificPrice.price,
 CargoState.cargo
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

CREATE OR REPLACE FUNCTION AddCargo (
 inBill integer,
 inAssembly integer,
 inCount float,
 inJobIndividual integer,
 inJournal integer,
 inEntry integer,
 inFromCargo integer
) RETURNS integer AS $$
DECLARE
 cargo_id integer;
BEGIN
 SELECT INTO cargo_id
  id AS cargo_id
 FROM Cargo
 WHERE bill = inBill
  AND assembly = inAssembly
  AND ((jobIndividual = inJobIndividual) OR (inJobIndividual IS NULL AND jobIndividual IS NULL))
  AND ((journal = inJournal) OR (inJournal IS NULL AND journal IS NULL))
  AND ((entry = inEntry) OR (inEntry IS NULL AND entry IS NULL))
 ORDER BY id DESC
 LIMIT 1
 ;

 IF cargo_id IS NULL THEN
  INSERT INTO Cargo (id, bill, count, assembly, jobIndividual, journal, entry)
  SELECT nextval('cargo_id_seq'),
   inBill,
   CASE WHEN inCount = 1 THEN
    NULL -- cargo record itself is a count of one unless overridden
   ELSE
    inCount
   END AS count,
   inAssembly,
   inJobIndividual,
   inJournal,
   inEntry
  FROM DUAL
  RETURNING id INTO cargo_id;
 ELSE
  INSERT INTO Cargo (id, bill, count, assembly, jobIndividual, journal, entry)
  SELECT cargo_id,
   inBill,
   inCount,
   inAssembly,
   inJobIndividual,
   inJournal,
   inEntry
  FROM DUAL
  ;
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
 inJobIndividual integer,
 inJournal integer,
 inEntry integer
) RETURNS integer AS $$
DECLARE
BEGIN
 RETURN AddCargo (inBill, inAssembly, inCount, inJobIndividual, inJournal, inEntry, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargo (
 inFromBill integer,
 inToBill integer,
 inItem integer,
 inCount float
) RETURNS integer AS $$
DECLARE
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
  Cargo.jobIndividual,
  Cargo.journal,
  Cargo.entry,
  Cargo.id)
 FROM Cargo
 LEFT JOIN CargoState ON CargoState.cargo = Cargo.id
 WHERE Cargo.bill = inFromBill
 GROUP BY Cargo.id,
  Cargo.assembly,
  Cargo.jobIndividual,
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
  Cargo.jobIndividual,
  Cargo.journal,
  Cargo.entry,
  Cargo.id)
 FROM Cargo
 WHERE Cargo.bill = inFromBill
  AND Cargo.assembly = inItem
 GROUP BY Cargo.id,
  Cargo.assembly,
  Cargo.jobIndividual,
  Cargo.journal,
  Cargo.entry
 ;
END IF;

RETURN inToBill;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION MoveCargoToChild (
 inFromBill integer,
 inItem integer,
 inCount float
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

 RETURN MoveCargo(inFromBill, to_bill, inItem, inCount);
END;
$$ LANGUAGE plpgsql;

-- New build of Business 0.2.1
SELECT SetSchemaVersion('Business', '0', '2', '1');
