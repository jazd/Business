-- Update from 0.2.7 to 0.2.8
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

 ALTER TABLE Business.SchemaVersion ADD COLUMN stop timestamp;

 SET search_path TO business, public;

 -- Check to be sure crrrent schema version is 0.2.7
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
   AND patch.value = '7'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.7';
 END IF;

END $$;

SET search_path TO business, public;

-- New tables
--
-- Table: Process
--
CREATE TABLE Process (
  id serial NOT NULL,
  name integer NOT NULL,
  description integer,
  version integer,
  PRIMARY KEY (id)
);

--
-- Table: Step
--
CREATE TABLE Step (
  id serial NOT NULL,
  name integer NOT NULL,
  description integer,
  unit integer,
  PRIMARY KEY (id)
);

--
-- Table: Variance
--
CREATE TABLE Variance (
  id serial NOT NULL,
  name integer NOT NULL,
  description integer,
  nominal integer,
  lower integer,
  upper integer,
  tolerance integer,
  value float(24),
  PRIMARY KEY (id)
);

--
-- Table: ProcessStep
--
CREATE TABLE ProcessStep (
  id serial NOT NULL,
  process integer NOT NULL,
  step integer NOT NULL,
  sequence smallint NOT NULL,
  expected integer,
  variance integer,
  -- Jump to this ProcessStep
  marginal integer,
  -- Jump to this ProcessStep
  failure integer,
  PRIMARY KEY (id)
);

--
-- Table: ProcessRun
--
CREATE TABLE ProcessRun (
  id serial NOT NULL,
  process integer NOT NULL,
  assembly integer NOT NULL,
  tester integer NOT NULL,
  supervisor bigint,
  started timestamp DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);

--
-- Table: ProcessRunResult
--
CREATE TABLE ProcessRunResult (
  id serial NOT NULL,
  run integer NOT NULL,
  processStep integer NOT NULL,
  result integer,
  pass boolean DEFAULT false,
  marginal boolean DEFAULT false,
  failure boolean DEFAULT false,
  created timestamp DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);


-- New constraints
ALTER TABLE Process ADD CONSTRAINT process_version FOREIGN KEY (version)
  REFERENCES Version (id) DEFERRABLE;

ALTER TABLE Variance ADD FOREIGN KEY (nominal)
  REFERENCES Attribute (id) DEFERRABLE;

ALTER TABLE Variance ADD FOREIGN KEY (lower)
  REFERENCES Attribute (id) DEFERRABLE;

ALTER TABLE Variance ADD FOREIGN KEY (upper)
  REFERENCES Attribute (id) DEFERRABLE;

ALTER TABLE ProcessStep ADD FOREIGN KEY (process)
  REFERENCES Process (id) DEFERRABLE;

ALTER TABLE ProcessStep ADD FOREIGN KEY (step)
  REFERENCES Step (id) DEFERRABLE;

ALTER TABLE ProcessStep ADD FOREIGN KEY (expected)
  REFERENCES Attribute (id) DEFERRABLE;

ALTER TABLE ProcessStep ADD FOREIGN KEY (variance)
  REFERENCES Variance (id) DEFERRABLE;

ALTER TABLE ProcessStep ADD FOREIGN KEY (marginal)
  REFERENCES ProcessStep (id) DEFERRABLE;

ALTER TABLE ProcessStep ADD FOREIGN KEY (failure)
  REFERENCES ProcessStep (id) DEFERRABLE;

ALTER TABLE ProcessRun ADD FOREIGN KEY (process)
  REFERENCES Process (id) DEFERRABLE;

ALTER TABLE ProcessRun ADD FOREIGN KEY (assembly)
  REFERENCES Part (id) DEFERRABLE;

ALTER TABLE ProcessRun ADD FOREIGN KEY (tester)
  REFERENCES AssemblyApplicationRelease (id) DEFERRABLE;

ALTER TABLE ProcessRunResult ADD FOREIGN KEY (run)
  REFERENCES ProcessRun (id) DEFERRABLE;

ALTER TABLE ProcessRunResult ADD FOREIGN KEY (processStep)
  REFERENCES ProcessStep (id) DEFERRABLE;

ALTER TABLE ProcessRunResult ADD FOREIGN KEY (result)
  REFERENCES Attribute (id) DEFERRABLE;

-- New views

-- New procedures

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


SELECT SetSchemaVersion('Business', '0', '2', '8');
