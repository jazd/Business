-- Entitlement — one version of a period. stopped IS NULL is current.
-- These procedures do not subscribe or unlist.

-- EntitlementGrant returns the current row for this individual, list, set, and source.
-- It inserts one when there is none.
CREATE OR REPLACE FUNCTION EntitlementGrant (
 inIndividual bigint,
 inListName varchar,
 inListSet varchar,
 inSource varchar,
 inStatus varchar,
 inStarts timestamp,
 inEnds timestamp,
 inBatch varchar
) RETURNS integer AS $$
DECLARE
 list_id integer;
 set_id integer;
 source_id integer;
 status_id integer;
 batch_id integer;
 entitlement_id integer;
BEGIN
 IF inIndividual IS NULL OR inListName IS NULL OR inSource IS NULL
  OR inStatus IS NULL OR inStarts IS NULL THEN
  RETURN NULL;
 END IF;
 list_id := (SELECT GetWord(inListName));
 source_id := (SELECT GetWord(inSource));
 status_id := (SELECT GetWord(inStatus));
 IF inListSet IS NOT NULL THEN
  set_id := (SELECT GetWord(inListSet));
 END IF;
 IF inBatch IS NOT NULL THEN
  batch_id := (SELECT GetSentence(inBatch));
 END IF;
 SELECT id INTO entitlement_id
 FROM Entitlement
 WHERE individual = inIndividual
  AND listName = list_id
  AND source = source_id
  AND stopped IS NULL
  AND (
   (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
  )
 LIMIT 1;
 IF entitlement_id IS NULL THEN
  PERFORM pg_advisory_lock(inIndividual);
  BEGIN
   INSERT INTO Entitlement (
    individual, listName, listSet, source, status, starts, ends, batch
   ) (
    SELECT inIndividual, list_id, set_id, source_id, status_id,
     inStarts, inEnds, batch_id
    FROM Dual
    LEFT JOIN Entitlement AS exists
     ON exists.individual = inIndividual
     AND exists.listName = list_id
     AND exists.source = source_id
     AND exists.stopped IS NULL
     AND (
      (exists.listSet = set_id) OR (exists.listSet IS NULL AND set_id IS NULL)
     )
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inIndividual);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inIndividual);
    RAISE;
  END;
  SELECT id INTO entitlement_id
  FROM Entitlement
  WHERE individual = inIndividual
   AND listName = list_id
   AND source = source_id
   AND stopped IS NULL
   AND (
    (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
   )
  LIMIT 1;
 END IF;
 RETURN entitlement_id;
END;
$$ LANGUAGE plpgsql;

-- EntitlementSet stops the current row with reason replaced and inserts the next version.
CREATE OR REPLACE FUNCTION EntitlementSet (
 inIndividual bigint,
 inListName varchar,
 inListSet varchar,
 inSource varchar,
 inStatus varchar,
 inStarts timestamp,
 inEnds timestamp,
 inBatch varchar
) RETURNS integer AS $$
DECLARE
 list_id integer;
 set_id integer;
 source_id integer;
 status_id integer;
 batch_id integer;
 reason_id integer;
 entitlement_id integer;
BEGIN
 IF inIndividual IS NULL OR inListName IS NULL OR inSource IS NULL
  OR inStatus IS NULL OR inStarts IS NULL THEN
  RETURN NULL;
 END IF;
 list_id := (SELECT GetWord(inListName));
 source_id := (SELECT GetWord(inSource));
 status_id := (SELECT GetWord(inStatus));
 reason_id := (SELECT GetWord('replaced'));
 IF inListSet IS NOT NULL THEN
  set_id := (SELECT GetWord(inListSet));
 END IF;
 IF inBatch IS NOT NULL THEN
  batch_id := (SELECT GetSentence(inBatch));
 END IF;
 PERFORM pg_advisory_lock(inIndividual);
 BEGIN
  UPDATE Entitlement
  SET stopped = NOW(),
   stopReason = reason_id
  WHERE individual = inIndividual
   AND listName = list_id
   AND source = source_id
   AND stopped IS NULL
   AND (
    (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
   );
  INSERT INTO Entitlement (
   individual, listName, listSet, source, status, starts, ends, batch
  ) VALUES (
   inIndividual, list_id, set_id, source_id, status_id,
   inStarts, inEnds, batch_id
  ) RETURNING id INTO entitlement_id;
  PERFORM pg_advisory_unlock(inIndividual);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(inIndividual);
   RAISE;
 END;
 RETURN entitlement_id;
END;
$$ LANGUAGE plpgsql;

-- EntitlementStop sets stopped and stopReason on the current row.
CREATE OR REPLACE FUNCTION EntitlementStop (
 inIndividual bigint,
 inListName varchar,
 inListSet varchar,
 inSource varchar,
 inStopReason varchar
) RETURNS integer AS $$
DECLARE
 list_id integer;
 set_id integer;
 source_id integer;
 reason_id integer;
 entitlement_id integer;
BEGIN
 IF inIndividual IS NULL OR inListName IS NULL OR inSource IS NULL THEN
  RETURN NULL;
 END IF;
 list_id := (SELECT GetWord(inListName));
 source_id := (SELECT GetWord(inSource));
 IF inListSet IS NOT NULL THEN
  set_id := (SELECT GetWord(inListSet));
 END IF;
 IF inStopReason IS NOT NULL THEN
  reason_id := (SELECT GetWord(inStopReason));
 END IF;
 UPDATE Entitlement
 SET stopped = NOW(),
  stopReason = reason_id
 WHERE individual = inIndividual
  AND listName = list_id
  AND source = source_id
  AND stopped IS NULL
  AND (
   (listSet = set_id) OR (listSet IS NULL AND set_id IS NULL)
  )
 RETURNING id INTO entitlement_id;
 RETURN entitlement_id;
END;
$$ LANGUAGE plpgsql;

-- EntitlementReference stores one name and value on a version.
-- The same name on that version returns the existing row.
CREATE OR REPLACE FUNCTION EntitlementReference (
 inEntitlement integer,
 inName varchar,
 inValue text
) RETURNS integer AS $$
DECLARE
 name_id integer;
 reference_id integer;
BEGIN
 IF inEntitlement IS NULL OR inName IS NULL OR inValue IS NULL THEN
  RETURN NULL;
 END IF;
 name_id := (SELECT GetWord(inName));
 SELECT id INTO reference_id
 FROM EntitlementReference
 WHERE entitlement = inEntitlement
  AND name = name_id
 LIMIT 1;
 IF reference_id IS NULL THEN
  PERFORM pg_advisory_lock(inEntitlement);
  BEGIN
   INSERT INTO EntitlementReference (entitlement, name, value) (
    SELECT inEntitlement, name_id, inValue
    FROM Dual
    LEFT JOIN EntitlementReference AS exists
     ON exists.entitlement = inEntitlement
     AND exists.name = name_id
    WHERE exists.id IS NULL
    LIMIT 1
   );
   PERFORM pg_advisory_unlock(inEntitlement);
  EXCEPTION
   WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(inEntitlement);
    RAISE;
  END;
  SELECT id INTO reference_id
  FROM EntitlementReference
  WHERE entitlement = inEntitlement
   AND name = name_id
  LIMIT 1;
 END IF;
 RETURN reference_id;
END;
$$ LANGUAGE plpgsql;
