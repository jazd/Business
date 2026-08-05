-- EST / certificates (diagram: est)
-- Device bring-up helpers: public key, CSR, client certificate
-- Assembled in lexicographic order of this directory; see README.md

-- Soft-stop prior active keys for assembly, then append new PEM
CREATE OR REPLACE FUNCTION PutAssemblyPublicKey (
 inAssembly integer,
 inPem varchar
) RETURNS void AS $$
BEGIN
 IF inAssembly IS NULL OR inPem IS NULL THEN
  RETURN;
 END IF;

 UPDATE AssemblyPublicKey
 SET stop = NOW()
 WHERE assembly = inAssembly
  AND stop IS NULL;

 INSERT INTO AssemblyPublicKey (assembly, pem)
 VALUES (inAssembly, inPem);
END;
$$ LANGUAGE plpgsql;

-- Insert CSR; return id
CREATE OR REPLACE FUNCTION PutCertificateSigningRequest (
 inPem varchar,
 inIndividual bigint
) RETURNS integer AS $$
DECLARE
 csr_id integer;
BEGIN
 IF inPem IS NULL THEN
  RETURN NULL;
 END IF;

 INSERT INTO CertificateSigningRequest (pem, individual)
 VALUES (inPem, inIndividual)
 RETURNING id INTO csr_id;

 RETURN csr_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION PutCertificateSigningRequest (
 inPem varchar,
 inIndividual bigint,
 inSession bigint
) RETURNS integer AS $$
DECLARE
 csr_id integer;
BEGIN
 IF inPem IS NULL THEN
  RETURN NULL;
 END IF;

 INSERT INTO CertificateSigningRequest (pem, individual, session)
 VALUES (inPem, inIndividual, inSession)
 RETURNING id INTO csr_id;

 RETURN csr_id;
END;
$$ LANGUAGE plpgsql;

-- Soft-stop prior active assembly–CSR links, then link assembly to CSR
CREATE OR REPLACE FUNCTION PutAssemblyCertificateSigningRequest (
 inAssembly integer,
 inCsr integer
) RETURNS void AS $$
BEGIN
 IF inAssembly IS NULL OR inCsr IS NULL THEN
  RETURN;
 END IF;

 UPDATE AssemblyCertificateSigningRequest
 SET stop = NOW()
 WHERE assembly = inAssembly
  AND stop IS NULL;

 INSERT INTO AssemblyCertificateSigningRequest (assembly, csr)
 VALUES (inAssembly, inCsr);
END;
$$ LANGUAGE plpgsql;

-- Client (or other) certificate row; type is a Word value (e.g. 'Client')
-- inDays is integer for easier call-site resolution (stored as Certificate.days smallint)
CREATE OR REPLACE FUNCTION PutCertificate (
 inCaPolicy integer,
 inType varchar,
 inIndividual bigint,
 inCsr integer,
 inStart timestamp,
 inDays integer,
 inO varchar,
 inOu varchar,
 inCn varchar,
 inEmail integer,
 inSerial varchar,
 inPem varchar
) RETURNS integer AS $$
DECLARE
 cert_id integer;
 type_id integer;
BEGIN
 IF inCaPolicy IS NULL OR inPem IS NULL THEN
  RETURN NULL;
 END IF;

 type_id := GetWord(inType);

 INSERT INTO Certificate (
  caPolicy,
  type,
  individual,
  csr,
  start,
  days,
  o,
  ou,
  cn,
  email,
  serial,
  pem
 ) VALUES (
  inCaPolicy,
  type_id,
  inIndividual,
  inCsr,
  inStart,
  inDays::smallint,
  inO,
  inOu,
  inCn,
  inEmail,
  inSerial,
  inPem
 )
 RETURNING id INTO cert_id;

 RETURN cert_id;
END;
$$ LANGUAGE plpgsql;
