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


DROP VIEW ADDRESSES;
ALTER TABLE Location ALTER COLUMN latitude TYPE NUMERIC(10,7);
ALTER TABLE Location ALTER COLUMN longitude TYPE NUMERIC(11,7);

--
-- View: Addresses
--
DROP VIEW IF EXISTS Addresses;
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
