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


