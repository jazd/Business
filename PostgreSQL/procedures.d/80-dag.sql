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

