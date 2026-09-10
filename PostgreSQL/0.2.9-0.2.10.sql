-- =============================================================================
-- Business schema upgrade: 0.2.9 -> 0.2.10 (PostgreSQL)
-- =============================================================================
--
-- Released hop 0.2.9 -> 0.2.10 (freeze after release). Next released hop is
-- PostgreSQL/0.2.10-0.2.11.sql. Living work is PostgreSQL/0.2.11-0.2.12.sql
-- (and SQLite/0.2.11-0.2.12.sql).
--
-- Fresh installs: make pgsqldb (pre + schema + procedures + post + Static).
-- Do not use this script for a greenfield install.
--
-- PRECONDITIONS
--   * Schema "business" exists
--   * Active SchemaVersion is Business 0.2.9 (stop IS NULL)
--   * Role can ALTER tables, DROP/CREATE views and functions
--   * Backup recommended for production
--
-- HOW TO RUN
--   psql -h <host> -U <user> -d <db> -v ON_ERROR_STOP=1 \
--     -f PostgreSQL/0.2.9-0.2.10.sql
--
-- ---------------------------------------------------------------------------
-- Applied by this script (existing 0.2.9 database)
-- ---------------------------------------------------------------------------
--
-- Applied sections below (this hop):
--  1) Commerce document views (BillDocuments, InvoiceLineDetail, Party*, BillReferences)
--  2) AssemblyPart.stop, created; assemblypart_assembly; Assemblies/AssemblyParts;
--     PutAssemblyPart; RemoveAssemblyPart
--
-- N) Schema version
--    * SetSchemaVersion('Business', '0', '2', '10') — last substantive step.
--
-- ---------------------------------------------------------------------------
-- Other release package changes (since tag 0.2.9)
-- ---------------------------------------------------------------------------
--
-- (Optional notes for packaging, diagrams, Bash helpers, README — not all
--  of these run inside this psql script.)
--
-- TESTING
--   * make pgsqldb on develop (fresh 0.2.10-shaped DB)
--   * Upgrade a copy of production (or test) 0.2.9 with this script
--   * BusinessSchema.PostgreSqlSuite (~24 intentional exceptions on
--     XcepteionRequired)
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

 -- Require current schema version 0.2.9
 IF NOT EXISTS (
  SELECT true
  FROM schemaversion
  JOIN word AS schema ON schema.id = schemaversion.schema
  JOIN version ON version.id = schemaversion.version
  JOIN word AS major ON major.id = version.major
  JOIN word AS minor ON minor.id = version.minor
  JOIN word AS patch ON patch.id = version.patch
  WHERE schema.value = 'Business'
   AND major.value = '0'
   AND minor.value = '2'
   AND patch.value = '9'
   AND stop IS NULL
 ) THEN
  RAISE EXCEPTION 'Not Schema Version 0.2.9';
 END IF;

END $$;

SET search_path TO business, public;

-- ---------------------------------------------------------------------------
-- 0.2.10: Commerce / invoice document views (schema.xml)
-- ---------------------------------------------------------------------------
-- Portable BillDocuments, InvoiceLineDetail, PartyAddresses, PartyPhones,
-- BillReferences — used by bookkeeper skill InvoicePDF and SQL exports.

CREATE OR REPLACE VIEW BillDocuments AS
SELECT
 Bill.id AS bill,
 Type.value AS documentType,
 DATE(Bill.created) AS documentDate,
 Bill.supplier,
 COALESCE(SupplierEnt.name, SupplierPeople.fullName) AS supplierName,
 Bill.consignee,
 COALESCE(ConsigneeEnt.name, ConsigneePeople.fullName) AS consigneeName,
 Source.id AS source,
 SourceType.value AS sourceType,
 Parent.id AS parent,
 ParentType.value AS parentType,
 (
  SELECT COALESCE(SUM(li.totalPrice), 0)
  FROM LineItems li
  WHERE li.bill = Bill.id
 ) AS subtotal,
 'INV-' || CAST(Bill.id AS varchar(20)) AS invoiceNumber
FROM Bill
JOIN I18NWord AS Type ON Type.id = Bill.type
LEFT JOIN Entities AS SupplierEnt ON SupplierEnt.individual = Bill.supplier
LEFT JOIN People AS SupplierPeople ON SupplierPeople.individual = Bill.supplier
LEFT JOIN Entities AS ConsigneeEnt ON ConsigneeEnt.individual = Bill.consignee
LEFT JOIN People AS ConsigneePeople ON ConsigneePeople.individual = Bill.consignee
LEFT JOIN Bill AS Source ON Source.id = Bill.source
LEFT JOIN I18NWord AS SourceType ON SourceType.id = Source.type
LEFT JOIN Bill AS Parent ON Parent.id = Bill.parent
LEFT JOIN I18NWord AS ParentType ON ParentType.id = Parent.type
WHERE Type.value IN (
 'Wish', 'Cart', 'Quote', 'Order',
 'Invoice', 'Receipt'
)
 AND COALESCE(SupplierEnt.name, SupplierPeople.fullName) IS NOT NULL
 AND COALESCE(ConsigneeEnt.name, ConsigneePeople.fullName) IS NOT NULL
;

CREATE OR REPLACE VIEW InvoiceLineDetail AS
SELECT
 li.bill,
 li.line,
 li.item AS product,
 li.version AS description,
 COALESCE(li.count, 1) AS qty,
 li.unitPrice AS rate,
 li.currentUnitPrice,
 li.totalPrice AS amount,
 li.outstanding,
 li.typeName,
 li.supplierName,
 li.consigneeName
FROM LineItems li
;

CREATE OR REPLACE VIEW PartyAddresses AS
SELECT
 ia.individual,
 Type.value AS addressType,
 a.address,
 a.line1,
 a.line2,
 a.line3,
 a.city,
 a.state,
 a.zipcode,
 a.postalcode,
 a.countrycode,
 ia.created
FROM IndividualAddress ia
JOIN Addresses a ON a.address = ia.address
LEFT JOIN I18NWord AS Type ON Type.id = ia.type
WHERE ia.stop IS NULL
;

CREATE OR REPLACE VIEW PartyPhones AS
SELECT
 ip.individual,
 Type.value AS phoneType,
 p.phone,
 p.local,
 p.international,
 ip.created
FROM IndividualPhone ip
JOIN Phones p ON p.phone = ip.phone
LEFT JOIN I18NWord AS Type ON Type.id = ip.type
WHERE ip.stop IS NULL
;

CREATE OR REPLACE VIEW BillReferences AS
SELECT
 br.id,
 br.bill,
 COALESCE(RefIdent.value, RefWord.value) AS referenceType,
 br.value,
 br.sequence,
 br.created
FROM BillReference br
LEFT JOIN Word AS RefIdent ON RefIdent.id = br.type
 AND RefIdent.culture IS NULL
LEFT JOIN I18NWord AS RefWord ON RefWord.id = br.type
WHERE br.stop IS NULL
;


-- ---------------------------------------------------------------------------
-- 0.2.10: AssemblyPart.stop, AssemblyPart.created; Assemblies / AssemblyParts;
--         PutAssemblyPart; RemoveAssemblyPart
-- ---------------------------------------------------------------------------
ALTER TABLE AssemblyPart
 ADD COLUMN IF NOT EXISTS stop timestamp NULL;

ALTER TABLE AssemblyPart
 ADD COLUMN IF NOT EXISTS created timestamp NOT NULL DEFAULT NOW();

COMMENT ON COLUMN AssemblyPart.stop IS
 'No longer associate this record with the assembly BOM. Used instead of DELETE.';

DO $$
BEGIN
 IF EXISTS (
  SELECT 1 FROM pg_constraint
  WHERE conname = 'assemplypart_assembly'
 ) THEN
  ALTER TABLE AssemblyPart RENAME CONSTRAINT assemplypart_assembly TO assemblypart_assembly;
 END IF;
END $$;

CREATE OR REPLACE VIEW Assemblies AS
SELECT DISTINCT AssemblyPart.assembly, Parent.name AS parentName,
 Assemblies.name,
 Assemblies.versionId AS version, Assemblies.version as VersionName, Assemblies.serial
FROM AssemblyPart
JOIN Parts AS Assemblies ON Assemblies.part = AssemblyPart.assembly
JOIN Parts AS Parent ON Parent.part = Assemblies.parent
;

CREATE OR REPLACE VIEW AssemblyParts AS
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
WHERE AssemblyPart.stop IS NULL
;

CREATE OR REPLACE FUNCTION RemoveAssemblyPart (
 inAssembly integer,
 inPart integer,
 inDesignator varchar
) RETURNS void AS $$
DECLARE
 designator_id integer;
 filter_designator boolean := false;
BEGIN
 IF inAssembly IS NULL THEN
  RETURN;
 END IF;
 IF inDesignator IS NOT NULL AND btrim(inDesignator) <> '' THEN
  filter_designator := true;
  designator_id := GetWord(inDesignator);
 END IF;
 PERFORM pg_advisory_lock(inAssembly);
 BEGIN
  UPDATE AssemblyPart
  SET stop = NOW()
  WHERE assembly = inAssembly
   AND stop IS NULL
   AND (inPart IS NULL OR part = inPart)
   AND (
    NOT filter_designator
    OR designator = designator_id
   );
  PERFORM pg_advisory_unlock(inAssembly);
 EXCEPTION
  WHEN OTHERS THEN
   PERFORM pg_advisory_unlock(inAssembly);
   RAISE;
 END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION RemoveAssemblyPart (
 inAssembly integer,
 inPart integer
) RETURNS void AS $$
BEGIN
 PERFORM RemoveAssemblyPart(inAssembly, inPart, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION RemoveAssemblyPart (
 inAssembly integer
) RETURNS void AS $$
BEGIN
 PERFORM RemoveAssemblyPart(inAssembly, NULL, NULL);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION PutAssemblyPart (
 inAssembly integer,
 inPart integer,
 inDesignator varchar,
 inQuantity integer
) RETURNS void AS $$
DECLARE designator_id integer;
BEGIN
 IF inAssembly IS NOT NULL AND inPart IS NOT NULL THEN
  designator_id := GetWord(inDesignator);
  PERFORM pg_advisory_lock(inAssembly);
  BEGIN
  IF designator_id IS NOT NULL THEN
   UPDATE AssemblyPart
   SET stop = NOW()
   WHERE assembly = inAssembly
    AND designator = designator_id
    AND stop IS NULL
    AND (
     part IS DISTINCT FROM inPart
     OR quantity IS DISTINCT FROM inQuantity
    );
  END IF;

  INSERT INTO AssemblyPart (assembly, part, designator, quantity) (
   SELECT inAssembly, inPart, designator_id, inQuantity
   FROM Dual
   LEFT JOIN AssemblyPart AS exists ON exists.assembly = inAssembly
    AND exists.part = inPart
    AND ((exists.designator = designator_id) OR (exists.designator IS NULL AND designator_id IS NULL))
    AND ((exists.quantity = inQuantity) OR (exists.quantity IS NULL AND inQuantity IS NULL))
    AND exists.stop IS NULL
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

-- Mark schema upgraded to 0.2.10
SELECT SetSchemaVersion('Business', '0', '2', '10');