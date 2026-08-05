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

