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


