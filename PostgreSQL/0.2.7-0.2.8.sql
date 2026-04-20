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

-- DROP TABLE IF EXISTS BillReference;
-- DROP TABLE IF EXISTS ProcessRunResult;
-- DROP TABLE IF EXISTS ProcessRun;
-- DROP TABLE IF EXISTS ProcessStep;
-- DROP TABLE IF EXISTS Variance;
-- DROP TABLE IF EXISTS Step;
-- DROP TABLE IF EXISTS Process;
-- DROP TABLE IF EXISTS ESTRequest;
-- DROP TABLE IF EXISTS AssemblyCertificate;
-- DROP TABLE IF EXISTS CACertificate;
-- DROP TABLE IF EXISTS Certificate;
-- DROP TABLE IF EXISTS CAPolicy;
-- DROP TABLE IF EXISTS CA;
-- DROP TABLE IF EXISTS AssemblyCertificateSigningRequest;
-- DROP TABLE IF EXISTS CertificateSigningRequest;
-- DROP TABLE IF EXISTS AssemblyPublicKey;
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

--
-- Table: BillReference
--
CREATE TABLE BillReference (
  id serial NOT NULL,
  bill integer NOT NULL,
  -- Order, Tracking, TaxID
  type integer,
  value character varying(80) NOT NULL,
  -- Order in a displayed list.
  sequence smallint,
  -- No longer associate this bill.
  stop timestamp,
  created timestamp DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);

--
-- Table: AssemblyPublicKey
--
CREATE TABLE AssemblyPublicKey (
  assembly integer NOT NULL,
  pem character varying NOT NULL,
  stop timestamp
);

--
-- Table: CertificateSigningRequest
--
CREATE TABLE CertificateSigningRequest (
  id serial NOT NULL,
  pem character varying NOT NULL,
  individual bigint,
  session bigint,
  PRIMARY KEY (id)
);

--
-- Table: AssemblyCertificateSigningRequest
--
CREATE TABLE AssemblyCertificateSigningRequest (
  assembly integer NOT NULL,
  csr integer NOT NULL,
  stop timestamp
);

--
-- Table: CA
--
CREATE TABLE CA (
  id serial NOT NULL,
  name integer NOT NULL,
  owner bigint,
  parent integer,
  PRIMARY KEY (id)
);

--
-- Table: CAPolicy
--
CREATE TABLE CAPolicy (
  id serial NOT NULL,
  ca integer NOT NULL,
  -- Override CA.name
  name integer,
  type integer,
  config integer,
  serial character varying,
  bits smallint,
  days smallint,
  crl bigint,
  est bigint,
  ocsp bigint,
  cp bigint,
  cps bigint,
  -- No longer associated with CA
  stop timestamp,
  PRIMARY KEY (id)
);

--
-- Table: Certificate
--
CREATE TABLE Certificate (
  id serial NOT NULL,
  caPolicy integer NOT NULL,
  type integer,
  individual bigint,
  csr integer,
  start timestamp,
  days smallint,
  c character varying,
  st character varying,
  l character varying,
  o character varying,
  ou character varying,
  cn character varying,
  email integer,
  serial character varying,
  pem character varying,
  fingerprint character varying,
  revoked timestamp,
  -- RFC 5280 codes
  reason integer,
  PRIMARY KEY (id)
);

--
-- Table: CACertificate
--
CREATE TABLE CACertificate (
  ca integer NOT NULL,
  certificate integer NOT NULL,
  -- No longer associated with CA
  stop timestamp
);

--
-- Table: AssemblyCertificate
--
CREATE TABLE AssemblyCertificate (
  assembly integer NOT NULL,
  certificate integer NOT NULL,
  stop timestamp,
  reason integer
);

--
-- Table: ESTRequest
--
CREATE TABLE ESTRequest (
  id serial NOT NULL,
  session bigint,
  operation integer,
  certificate integer NOT NULL,
  csr integer NOT NULL,
  issued integer NOT NULL,
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

ALTER TABLE BillReference ADD FOREIGN KEY (bill)
  REFERENCES Bill (id) DEFERRABLE;

ALTER TABLE AssemblyPublicKey ADD CONSTRAINT assemblypublickey_assembly FOREIGN KEY (assembly)
  REFERENCES Part (id) DEFERRABLE;

ALTER TABLE CertificateSigningRequest ADD CONSTRAINT certificatesigningrequest_session FOREIGN KEY (session)
  REFERENCES Session (id) DEFERRABLE;

ALTER TABLE AssemblyCertificateSigningRequest ADD CONSTRAINT assemblycertificatesigningrequest_assembly FOREIGN KEY (assembly)
  REFERENCES Part (id) DEFERRABLE;

ALTER TABLE AssemblyCertificateSigningRequest ADD CONSTRAINT assemblycertificatesigningrequest_csr FOREIGN KEY (csr)
  REFERENCES CertificateSigningRequest (id) DEFERRABLE;

ALTER TABLE CA ADD CONSTRAINT ca_parent FOREIGN KEY (parent)
  REFERENCES CA (id) DEFERRABLE;

ALTER TABLE CA ADD CONSTRAINT ca_name FOREIGN KEY (name)
  REFERENCES Entity (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_ca FOREIGN KEY (ca)
  REFERENCES CA (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_config FOREIGN KEY (config)
  REFERENCES Path (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_name FOREIGN KEY (name)
  REFERENCES Entity (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_crl FOREIGN KEY (crl)
  REFERENCES Path (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_est FOREIGN KEY (est)
  REFERENCES Path (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_ocsp FOREIGN KEY (ocsp)
  REFERENCES Path (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_cp FOREIGN KEY (cp)
  REFERENCES Path (id) DEFERRABLE;

ALTER TABLE CAPolicy ADD CONSTRAINT capolicy_cps FOREIGN KEY (cps)
  REFERENCES Path (id) DEFERRABLE;

ALTER TABLE Certificate ADD CONSTRAINT certificate_capolicy FOREIGN KEY (caPolicy)
  REFERENCES CAPolicy (id) DEFERRABLE;

ALTER TABLE Certificate ADD CONSTRAINT certificate_csr FOREIGN KEY (csr)
  REFERENCES CertificateSigningRequest (id) DEFERRABLE;

ALTER TABLE Certificate ADD FOREIGN KEY (email)
  REFERENCES Email (id) DEFERRABLE;

ALTER TABLE CACertificate ADD CONSTRAINT cacertificate_ca FOREIGN KEY (ca)
  REFERENCES CA (id) DEFERRABLE;

ALTER TABLE CACertificate ADD CONSTRAINT cacertificate_certificate FOREIGN KEY (certificate)
  REFERENCES Certificate (id) DEFERRABLE;

ALTER TABLE AssemblyCertificate ADD CONSTRAINT assemblycertificate_assembly FOREIGN KEY (assembly)
  REFERENCES Part (id) DEFERRABLE;

ALTER TABLE AssemblyCertificate ADD CONSTRAINT assemblycertificate_certificate FOREIGN KEY (certificate)
  REFERENCES Certificate (id) DEFERRABLE;

ALTER TABLE ESTRequest ADD CONSTRAINT estrequest_session FOREIGN KEY (session)
  REFERENCES Session (id) DEFERRABLE;

ALTER TABLE ESTRequest ADD CONSTRAINT estrequest_certificate FOREIGN KEY (certificate)
  REFERENCES Certificate (id) DEFERRABLE;

ALTER TABLE ESTRequest ADD CONSTRAINT estrequest_csr FOREIGN KEY (csr)
  REFERENCES CertificateSigningRequest (id) DEFERRABLE;

ALTER TABLE ESTRequest ADD CONSTRAINT estrequest_issued FOREIGN KEY (issued)
  REFERENCES Certificate (id) DEFERRABLE;

-- Updated and New views
DROP VIEW IF EXISTS CAs;
DROP VIEW IF EXISTS Certificates;
DROP VIEW IF EXISTS LineItems;
DROP VIEW IF EXISTS LineItemsRaw;
DROP VIEW IF EXISTS Bills;
DROP VIEW IF EXISTS EdgeIndividuals;
DROP VIEW IF EXISTS Edges;
DROP VIEW IF EXISTS JournalReport;
DROP VIEW IF EXISTS LedgerReport;
DROP VIEW IF EXISTS LedgerBalance;
DROP VIEW IF EXISTS JournalEntries;
DROP VIEW IF EXISTS Books;
DROP VIEW IF EXISTS Journals;
DROP VIEW IF EXISTS Ledgers;
DROP VIEW IF EXISTS Accounts;
DROP VIEW IF EXISTS Periods;
DROP VIEW IF EXISTS AssemblyParts;
DROP VIEW IF EXISTS AssemblyApplicationReleases;
DROP VIEW IF EXISTS Assemblies;
DROP VIEW IF EXISTS Parts;
DROP VIEW IF EXISTS ParsedAgentString;
DROP VIEW IF EXISTS Sessions;
DROP VIEW IF EXISTS ParsedAgentStringShort;
DROP VIEW IF EXISTS ApplicationReleases;
DROP VIEW IF EXISTS Applications;
DROP VIEW IF EXISTS Versions;
DROP VIEW IF EXISTS Addresses;
DROP VIEW IF EXISTS List;
DROP VIEW IF EXISTS PeopleEvent;
DROP VIEW IF EXISTS People;
DROP VIEW IF EXISTS PeriodSpans;
DROP VIEW IF EXISTS I8NSentence;
DROP VIEW IF EXISTS I8NWord;

--
-- View: I18NWord
--
CREATE VIEW I18NWord ( id, defaultCulture, clientCulture, resultCulture, value ) AS
SELECT WordDefault.id,
 WordDefault.culture AS defaultCulture,
 ClientCulture() AS clientCulture,
 COALESCE(Word.culture, WordDefault.culture) AS resultCulture,
 COALESCE(Word.value, WordDefault.value) AS value
FROM Word AS WordDefault
LEFT JOIN Word ON Word.id = WordDefault.id
 AND Word.culture = ClientCulture()
WHERE WordDefault.culture = 1033
;

--
-- View: I18NSentence
--
CREATE VIEW I18NSentence ( id, defaultCulture, clientCulture, resultCulture, value, length ) AS
SELECT SentenceDefault.id,
 SentenceDefault.culture AS defaultCulture,
 ClientCulture() AS clientCulture,
 COALESCE(Sentence.culture, SentenceDefault.culture) AS resultCulture,
 COALESCE(Sentence.value, SentenceDefault.value) AS value,
 COALESCE(Sentence.length, SentenceDefault.length) AS length
FROM Sentence AS SentenceDefault
LEFT JOIN Sentence ON Sentence.id = SentenceDefault.id
 AND Sentence.culture = ClientCulture()
WHERE SentenceDefault.culture = 1033
;

--
-- View: PeriodSpans
--
CREATE VIEW PeriodSpans ( period, name, periodname, span, exclude, monthdaymonth, day, weekofmonth, dayofweekstart, dayofweekstop, dayofmonth, month, monthyear, daterangestart, daterangestop, timeofdaystart, timeofdaystop ) AS
SELECT PeriodName.period, PeriodName.name, I18NSentence.value AS periodName,
 Period.span, Period.exclude,
 MonthDay.month AS MonthDaymonth, MonthDay.day, MonthDay.weekOfMonth,
 DayOfWeek.start AS dayOfWeekStart, DayOfWeek.stop AS dayOfWeekStop, DayOfWeek.dayOfMonth,
 Month.month, Month.year AS monthYear,
 DateRange.start AS dateRangeStart, DateRange.stop AS dateRangeStop,
 TimeOfDay.start AS timeOfDayStart, TimeOfDay.stop AS timeOfDayStop
FROM Period
JOIN PeriodName ON PeriodName.period = Period.id
JOIN I18NSentence ON I18NSentence.id = PeriodName.name
LEFT JOIN MonthDay  ON MonthDay.id  = Period.span
LEFT JOIN DayOfWeek ON DayOfWeek.id = Period.span
LEFT JOIN Month     ON Month.id     = Period.span
LEFT JOIN DateRange ON DateRange.id = Period.span
LEFT JOIN TimeOfDay ON TimeOfDay.id = Period.span
;

--
-- View: People
--
CREATE VIEW People ( individual, name, goesBy, birthday, in_days, fullName, honorific, given, middle, family, suffix, post, honorificvalue, givenvalue, middlevalue, familyvalue, suffixvalue, postvalue, birth, death, aged, created ) AS
SELECT Individual.id AS individual, Name.id AS name,
 COALESCE(GoesBy.value,Given.value,Family.value) AS goesBy,
 birthday(CAST(birth AS date),CAST(NOW() AS date)) AS birthday,
 days_until_birthday(CAST(birth AS date), CAST(NOW() AS date)) AS in_days,
 COALESCE(Honorific.value,'') ||
  CASE WHEN (Honorific.value IS NOT NULL AND Given.value IS NULL AND Middle.value IS NULL) THEN ' ' ELSE '' END ||
  COALESCE(CASE WHEN (Honorific.value IS NOT NULL) THEN ' ' ELSE '' END || Given.value,'') ||
  COALESCE(CASE WHEN (Given.value IS NOT NULL) THEN ' ' ELSE '' END || Middle.value,'') ||
  CASE WHEN (Given.value IS NOT NULL AND Middle.value IS NULL) THEN ' ' ELSE '' END ||
  COALESCE(CASE WHEN (Middle.value IS NOT NULL) THEN ' ' ELSE '' END  || Family.value,'') ||
  COALESCE(CASE WHEN (Family.value IS NOT NULL) THEN ' ' ELSE '' END || Suffix.value,'') ||
  COALESCE(CASE WHEN (Suffix.value IS NOT NULL) THEN ' ' ELSE '' END || Post.value,'')
  AS fullName,
 Individual.prefix AS honorific,
 Name.given, Name.middle, Name.family,
 Individual.suffix,
 Individual.post,
 Honorific.value AS honorificValue,
 Given.value AS givenValue, Middle.value AS middleValue, Family.value AS familyValue,
 Suffix.value AS suffixValue,
 Post.value AS postValue,
 birth, death,
 COALESCE(age(death,birth),age(birth)) AS aged,
 Individual.created
FROM Individual
JOIN Name ON Name.id = Individual.name
LEFT JOIN Given ON Given.id = Name.given
LEFT JOIN Given AS Middle ON Middle.id = Name.middle
LEFT JOIN Given AS GoesBy ON GoesBy.id = Individual.goesBy
LEFT JOIN Family ON Family.id = Name.family
LEFT JOIN I18NWord AS Honorific ON Honorific.id = Individual.prefix
LEFT JOIN I18NWord AS Suffix ON Suffix.id = Individual.suffix
LEFT JOIN I18NWord AS Post ON Post.id = Individual.post
WHERE Individual.nameChange IS NULL
 OR Individual.nameChange > NOW()
;

--
-- View: PeopleEvent
--
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
 LEFT JOIN I18NWord AS Honorific ON Honorific.id = IndividualPersonEvent.honorific
 LEFT JOIN I18NWord AS Suffix ON Suffix.id = IndividualPersonEvent.suffix
 LEFT JOIN I18NWord AS Post ON Post.id = IndividualPersonEvent.post
 LEFT JOIN I18NWord AS Born ON Born.value = 'Born' AND birth = event
 LEFT JOIN I18NWord AS Death ON Death.value = 'Died' AND death = event
 LEFT JOIN I18NWord AS Change ON Change.value = 'Changed name'
;

--
-- View: List
--
CREATE VIEW List ( id, individual, listName, listNameValue, listSet, listSetValue, sequence, send, created ) AS
SELECT ListIndividual.id,
 ListIndividual.individual,
 ListIndividualName.name AS listName,
 Name.value AS listNameValue,
 ListIndividualName.listSet,
 ListSet.value AS listSetValue,
 ListIndividualName.sequence,
 CASE WHEN SendField.value IS NULL THEN 'to' ELSE SendField.value END AS send,
 ListIndividual.created
FROM ListIndividual
JOIN ListIndividualName ON ListIndividualName.ListIndividual = ListIndividual.id
 AND ListIndividualName.optinStyle = 1
JOIN I18NWord AS Name ON ListIndividualName.name = Name.id
LEFT JOIN I18NWord AS ListSet ON ListIndividualName.listSet = ListSet.id
LEFT JOIN Word AS SendField ON SendField.id = ListIndividual.type
 AND SendField.culture IS NULL
LEFT JOIN ListIndividual AS disable ON disable.individual = ListIndividual.individual
 AND disable.id IS NULL
 AND disable.unlist IS NULL
WHERE disable.individual IS NULL
 AND ListIndividual.unlist IS NULL
;

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
JOIN I18NWord AS City ON City.id = Postal.city
JOIN I18NWord AS State ON State.id = Postal.state
LEFT JOIN I18NWord AS StateAbbr ON StateAbbr.id = Postal.stateAbbreviation
LEFT JOIN Location AS AddressLocation On AddressLocation.id = Address.location
LEFT JOIN Location AS PostalLocation ON PostalLocation.id = Postal.location
LEFT JOIN Location AS CountryLocation ON CountryLocation.id = Country.location
;

--
-- View: Versions
--
CREATE VIEW Versions ( version, name, value, major, minor, patch ) AS
SELECT Version.id AS version, name.value AS name,
 major.value ||
  COALESCE('.' || minor.value, '') ||
  COALESCE('.' || patch.value, '')
 AS value,
 major.value AS major,
 minor.value AS minor,
 patch.value AS patch
FROM Version
LEFT JOIN I18NWord AS name ON name.id = Version.name
LEFT JOIN I18NWord AS major ON major.id = Version.major
LEFT JOIN I18NWord AS minor ON minor.id = Version.minor
LEFT JOIN I18NWord AS patch ON patch.id = Version.patch
;

--
-- View: Applications
--
CREATE VIEW Applications ( application, name, goesby, path ) AS
   SELECT Application.id AS application,
    Name.value AS name,
    Application.goesBy,
    Application.path
   FROM Application
   JOIN I18NWord AS Name on Name.id = Application.name
;

--
-- View: ApplicationReleases
--
CREATE VIEW ApplicationReleases ( applicationrelease, application, release, name, goesby, applicationpath, versionid, buildid, versionname, buildname ) AS
   SELECT ApplicationRelease.id AS applicationRelease,
    ApplicationRelease.application,
    ApplicationRelease.release,
    Applications.name,
    Applications.goesBy,
    Applications.path AS applicationPath,
    Release.version AS versionId,
    Release.build AS buildId,
    Versions.value as versionName,
    Build.value as buildName
   FROM ApplicationRelease
   JOIN Applications ON Applications.application = ApplicationRelease.application
   JOIN Release ON Release.id = ApplicationRelease.release
   JOIN Versions ON Versions.version = Release.version
   JOIN I18NWord AS Build ON Build.id = Release.build
;

--
-- View: ParsedAgentStringShort
--
CREATE VIEW ParsedAgentStringShort ( agentstring, deviceid, device, osid, os, agentid, agent, deviceversion, osapplicationrelease, agentapplicationrelease ) AS
SELECT AgentString.id AS agentString,
 device.id AS deviceid, deviceName.value AS device,
 OS.id AS osid, OSName.value AS OS,
 Agent.id AS agentid, AgentName.value AS agent,
 device.version AS deviceversion,
 deviceOS.applicationrelease AS osApplicationRelease,
 agentApplicationRelease.id AS agentApplicationRelease
FROM AgentString
JOIN AssemblyApplicationRelease AS deviceAgent ON deviceAgent.id = AgentString.agent
JOIN Part AS device ON device.id = deviceAgent.assembly
JOIN I18NSentence AS deviceName ON deviceName.id = device.name
JOIN AssemblyApplicationRelease AS deviceOS ON deviceOS.id = deviceAgent.parent
JOIN ApplicationRelease AS OSapplicationRelease ON OSapplicationRelease.id = deviceOS.applicationRelease
JOIN Application AS OS ON OS.id = OSapplicationRelease.application
JOIN I18NWord AS OSName ON OSName.id = OS.name
JOIN ApplicationRelease AS agentApplicationRelease ON agentApplicationRelease.id = deviceAgent.applicationRelease
JOIN Application AS Agent On Agent.id = agentApplicationRelease.application
JOIN I18NWord AS AgentName ON AgentName.id = Agent.name
;

--
-- View: ParsedAgentString
--
CREATE VIEW ParsedAgentString ( agentstring, deviceid, deviceversion, device, deviceersionname, osid, osversion, os, osversionname, agentid, agentversion, agent, agentversionname ) AS
SELECT agentstring,
 deviceid, deviceversion, device, deviceversionname.value as deviceersionname,
 osid, OSRelease.version AS osversion, os, OSVersion.value AS osversionname,
 agentid, AgentVersion.version AS agentversion, agent, AgentVersion.value agentversionname
FROM ParsedAgentStringShort
JOIN ApplicationRelease AS OSApplicatonRelease ON OSApplicatonRelease.id = osapplicationrelease
JOIN ApplicationRelease AS AgentApplicationRelease ON AgentApplicationRelease.id = agentApplicationRelease
LEFT JOIN Versions AS deviceversionname ON deviceversionname.version = deviceversion
LEFT JOIN Release AS OSRelease ON OSRelease.id = OSApplicatonRelease.release
LEFT JOIN Versions AS OSVersion ON OSVersion.version = OSRelease.version
LEFT JOIN Release AS AgentRelease ON AgentRelease.id = AgentApplicationRelease.release
LEFT JOIN Versions AS AgentVersion ON AgentVersion.version = AgentRelease.version
;

--
-- View: Sessions
--
CREATE VIEW Sessions ( session, token, siteapplicationrelease, agentstring, deviceid, device, osid, os, agentid, agent, referring, referrringurl, fromaddress, credential, individual, username, email, created, touched ) AS
SELECT Session.id AS session,
 SessionToken.token, SessionToken.siteapplicationrelease,
 SessionCredential.agentstring,
 deviceid, ParsedAgentStringShort.device, osid, ParsedAgentStringShort.os, agentid, ParsedAgentStringShort.agent,
 SessionCredential.referring, URL.value AS referrringURL,
 SessionCredential.fromaddress,
 SessionCredential.credential, Credential.individual,  Credential.username,
 EmailAddress.value AS email,
 COALESCE(SessionToken.created, Session.created) AS created, Session.touched
FROM Session
CROSS JOIN SessionCredential
LEFT JOIN SessionToken ON SessionToken.session = Session.id
LEFT JOIN ParsedAgentStringShort ON ParsedAgentStringShort.agentstring = SessionCredential.agentstring
LEFT JOIN Credential ON Credential.id = SessionCredential.credential
LEFT JOIN EmailAddress ON EmailAddress.email = Credential.email
LEFT JOIN URL ON URL.path = SessionCredential.referring
WHERE Session.id = SessionCredential.session
;

--
-- View: Parts
--
CREATE VIEW Parts ( part, parent, name, nameId, version, versionId, serial, created ) AS
SELECT Part.id AS part, Part.parent,
 I18NSentence.value AS name, Part.name AS nameId,
 CASE WHEN (Versions.name IS NOT NULL) THEN Versions.name ELSE '' END ||
 CASE WHEN (Versions.name IS NOT NULL) THEN ' ' ELSE '' END ||
 CASE WHEN (Versions.value IS NOT NULL) THEN Versions.value ELSE '' END AS version,
 Part.version AS versionId,
 Part.serial, Part.created
FROM Part
JOIN I18NSentence ON I18NSentence.id = Part.name
LEFT JOIN Versions ON Versions.version = Part.version
;

--
-- View: Assemblies
--
CREATE VIEW Assemblies ( assembly, parentName, name, version, versionName, serial ) AS
SELECT DISTINCT AssemblyPart.assembly, Parent.name AS parentName,
 Assemblies.name,
 Assemblies.versionId AS version, Assemblies.version as VersionName, Assemblies.serial
FROM AssemblyPart
JOIN Parts AS Assemblies ON Assemblies.part = AssemblyPart.assembly
JOIN Parts AS Parent ON Parent.part = Assemblies.parent
;

--
-- View: AssemblyApplicationReleases
--
CREATE VIEW AssemblyApplicationReleases ( assemblyapplicationrelease, applicationrelease, assembly, application, release, assemblyparent, assemblyname, assemblyverionid, assemblyversion, serial, applicationid, applicationname, goesby, applicationpath, applicationversionid, applicationversionname, buildname, created ) AS
   SELECT AssemblyApplicationRelease.id AS assemblyApplicationRelease,
    AssemblyApplicationRelease.applicationRelease,
    Assembly.part AS assembly,
    ApplicationReleases.application,
    ApplicationReleases.release,
    Assembly.parent AS assemblyParent,
    Assembly.name AS assemblyName,
    Assembly.versionId AS assemblyVerionId,
    Assembly.version AS assemblyVersion,
    Assembly.serial,
    ApplicationReleases.application AS applicationId,
    ApplicationReleases.name AS applicationName,
    ApplicationReleases.goesBy,
    ApplicationReleases.applicationPath,
    ApplicationReleases.versionId AS applicationVersionId,
    ApplicationReleases.versionName AS applicationVersionName,
    ApplicationReleases.buildName,
    AssemblyApplicationRelease.created
   FROM AssemblyApplicationRelease
   JOIN Parts AS Assembly ON Assembly.part = AssemblyApplicationRelease.assembly
   JOIN ApplicationReleases ON ApplicationReleases.applicationrelease = AssemblyApplicationRelease.applicationrelease
;

--
-- View: AssemblyParts
--
CREATE VIEW AssemblyParts ( assembly, parentName, assemblyName, assemblyVersion, assemblyVersionName, assemblySerial, quantity, designator, part, partName, version, versionName, serial ) AS
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
;

--
-- View: Periods
--
CREATE VIEW Periods ( period, name, periodname ) AS
SELECT PeriodName.period, PeriodName.name, I18NSentence.value AS periodName
FROM PeriodName
LEFT JOIN I18NSentence ON I18NSentence.id = PeriodName.name
;

--
-- View: Accounts
--
CREATE VIEW Accounts ( account, name, type, typeName, individual, individualName, individualAccountType, individualAccountTypeName, credit, debitIncrease, debitDecrease, creditIncrease, creditDecrease ) AS
SELECT AccountName.account,
 I18NSentence.value AS name,
 AccountName.type,
 TypeName.value AS typeName,
 IndividualAccount.individual,
 COALESCE(People.fullname, Entities.name) AS individualName,
 IndividualAccount.type AS individualAccountType,
 IndividualAccountType.value AS individualAccountTypeName,
 AccountName.credit,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitIncrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS debitDecrease,
 CASE WHEN AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditIncrease,
 CASE WHEN NOT AccountName.credit THEN
  1
 ELSE
  NULL
 END AS creditDecrease
FROM AccountName
JOIN I18NSentence ON I18NSentence.id = AccountName.name
JOIN I18NWord AS TypeName ON TypeName.id = AccountName.type
LEFT JOIN IndividualAccount ON IndividualAccount.account = AccountName.account
 AND IndividualAccount.stop IS NULL
LEFT JOIN People ON People.individual = IndividualAccount.individual
LEFT JOIN Entities ON Entities.individual = IndividualAccount.individual
LEFT JOIN I18NWord AS IndividualAccountType ON IndividualAccountType.id = IndividualAccount.type
;

--
-- View: Ledgers
--
CREATE VIEW Ledgers ( ledger, name, sequence, account, accountname, type, typename, credit, debitincrease, debitdecrease, creditincrease, creditdecrease ) AS
SELECT LedgerName.ledger,
 I18NSentence.value AS name,
 LedgerAccount.sequence,
 Accounts.account,
 Accounts.name AS accountName,
 Accounts.type,
 Accounts.typeName,
 Accounts.credit,
 Accounts.debitIncrease,
 Accounts.debitDecrease,
 Accounts.creditIncrease,
 Accounts.creditDecrease
FROM LedgerName
JOIN I18NSentence ON I18NSentence.id = LedgerName.name
JOIN LedgerAccount ON LedgerAccount.ledger = LedgerName.ledger
JOIN Accounts ON Accounts.account = LedgerAccount.account
;

--
-- View: Journals
--
CREATE VIEW Journals ( journal, name ) AS
SELECT JournalName.journal,
 I18NSentence.value AS name
FROM JournalName
JOIN I18NSentence ON I18NSentence.id = JournalName.name
;

--
-- View: Books
--
CREATE VIEW Books ( book, name, journal, journalname, split, increase, increasename, increasetype, increasecredit, increasedebitincrease, increasedebitdecrease, increasecreditincrease, increasecreditdecrease, decrease, decreasename, decreasetype, decreasecredit, decreasedebitincrease, decreasedebitdecrease, decreasecreditincrease, decreasecreditdecrease ) AS
SELECT BookName.book,
 I18NSentence.value AS name,
 BookName.journal,
 Journals.name AS journalName,
 COALESCE(BookAccount.split, 1) AS split,
 BookAccount.increase,
 Increase.name AS increaseName,
 Increase.type AS increaseType,
 Increase.credit AS increaseCredit,
 Increase.debitIncrease  AS increaseDebitIncrease,
 Increase.debitDecrease  AS increaseDebitDecrease,
 Increase.creditIncrease AS increaseCreditIncrease,
 Increase.creditDecrease  AS increaseCreditDecrease,
 BookAccount.decrease,
 Decrease.name AS decreaseName,
 Decrease.type AS decreaseType,
 Decrease.credit AS decreaseCredit,
 Decrease.debitIncrease  AS decreaseDebitIncrease,
 Decrease.debitDecrease  AS decreaseDebitDecrease,
 Decrease.creditIncrease AS decreaseCreditIncrease,
 Decrease.creditDecrease AS decreaseCreditDecrease
FROM BookName
JOIN I18NSentence ON I18NSentence.id = BookName.name
JOIN Journals ON Journals.journal = BookName.journal
JOIN BookAccount ON BookAccount.book = BookName.book
LEFT JOIN Accounts AS Increase ON Increase.account = BookAccount.increase
LEFT JOIN Accounts AS Decrease  ON Decrease.account  = BookAccount.decrease
;

--
-- View: JournalEntries
--
CREATE VIEW JournalEntries ( id, journal, journalname, book, bookname, entry, account, accountname, type, typename, ledger, ledgername, rightside, debit, credit, posted, created ) AS
SELECT JournalEntry.id,
 JournalEntry.journal,
 JournalNameString.value AS journalName,
 JournalEntry.book,
 BookNameString.value AS bookName,
 JournalEntry.entry,
 JournalEntry.account,
 AccountNameString.value AS accountName,
 AccountName.type,
 AccountTypeName.value AS typeName,
 LedgerJournal.ledger,
 LedgerNameString.value AS ledgerName,
 JournalEntry.credit AS rightSide,
 CASE WHEN NOT JournalEntry.credit THEN
  JournalEntry.amount
 END AS debit,
 CASE WHEN JournalEntry.credit THEN
  JournalEntry.amount
 END AS credit,
 JournalEntry.posted,
 JournalEntry.created
FROM JournalEntry
JOIN AccountName ON AccountName.account = JournalEntry.account
JOIN I18NSentence AS AccountNameString ON AccountNameString.id = AccountName.name
JOIN I18NWord AS AccountTypeName ON AccountTypeName.id = AccountName.type
JOIN JournalName ON JournalName.journal = JournalEntry.journal
JOIN I18NSentence AS JournalNameString ON JournalNameString.id = JournalName.name
LEFT JOIN BookName ON BookName.book = JournalEntry.book
LEFT JOIN I18NSentence AS BookNameString ON BookNameString.id = BookName.name
LEFT JOIN LedgerJournal ON LedgerJournal.journal = JournalEntry.journal
LEFT JOIN LedgerName ON LedgerName.ledger = LedgerJournal.ledger
LEFT JOIN I18NSentence AS LedgerNameString ON LedgerNameString.id = LedgerName.name
;

--
-- View: LedgerBalance
--
CREATE VIEW LedgerBalance ( ledger, ledgername, sequence, account, accountname, type, typename, debit, credit ) AS
SELECT Ledgers.ledger,
 Ledgers.name AS ledgerName,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName,
 SUM(JournalEntries.debit) AS debit,
 SUM(JournalEntries.credit) AS credit
FROM JournalEntries
JOIN Ledgers ON Ledgers.ledger = JournalEntries.ledger
 AND Ledgers.type = JournalEntries.type
WHERE JournalEntries.posted IS NULL
GROUP BY Ledgers.ledger,
 Ledgers.name,
 Ledgers.sequence,
 Ledgers.account,
 Ledgers.accountName,
 Ledgers.type,
 Ledgers.typeName
;

--
-- View: LedgerReport
--
CREATE VIEW LedgerReport ( ledger, sequence, ledgername, accountname, typename, debit, credit ) AS
SELECT ledger,
 sequence,
 ledgername,
 accountname,
 typename,
 debit,
 credit
FROM LedgerBalance
UNION ALL
SELECT ledger,
 NULL AS sequence,
 ledgerName,
 'Total' AS accountName,
 NULL AS typeName,
 SUM(debit) AS debit,
 SUM(credit) AS credit
FROM LedgerBalance
GROUP BY ledger,
 ledgerName
;

--
-- View: JournalReport
--
CREATE VIEW JournalReport ( journal, journalName, entry, account, type, ledger, ledgerName, debit, credit, rightside, created ) AS
SELECT journal,
 journalName,
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
 NULL AS journalName,
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
-- View: Edges
--
CREATE VIEW Edges ( edge, startName, stopName, hops, entry, direct, exit, start, stop ) AS
SELECT Edge.id AS edge,
 StartVertexNameString.value AS startName,
 StopVertexNameString.value AS stopName,
 hops,
 entry,
 direct,
 exit,
 start,
 stop
FROM Edge
JOIN VertexName AS StartVertexName ON StartVertexName.vertex = Edge.start
JOIN I18NSentence AS StartVertexNameString ON StartVertexNameString.id = StartVertexName.name
JOIN VertexName AS StopVertexName ON StopVertexName.vertex = Edge.stop
LEFT JOIN I18NSentence AS StopVertexNameString ON StopVertexNameString.id = StopVertexName.name
;

--
-- View: EdgeIndividuals
--
CREATE VIEW EdgeIndividuals ( edge, startname, stopname, startindividual, startindividualname, starttype, stopindividual, stopindividualname, stoptype, hops, entry, direct, exit ) AS
SELECT Edge.id AS edge,
 StartVertexNameString.value AS startName,
 StopVertexNameString.value AS stopName,
 StartIndividualVertex.individual AS startIndividual,
 StartType.value AS startType,
 COALESCE(StartPeople.fullname, StartEntities.name) AS startIndividualName,
 StopIndividualVertex.individual AS stopIndividual,
 COALESCE(StopPeople.fullname, StopEntities.name) AS stopIndividualName,
 StopType.value AS stopType,
 hops,
 entry,
 direct,
 exit,
 start,
 Edge.stop
FROM Edge
JOIN VertexName AS StartVertexName ON StartVertexName.vertex = Edge.start
JOIN VertexName AS StopVertexName ON StopVertexName.vertex = Edge.stop
LEFT JOIN I18NSentence AS StartVertexNameString ON StartVertexNameString.id = StartVertexName.name
LEFT JOIN I18NSentence AS StopVertexNameString ON StopVertexNameString.id = StopVertexName.name
LEFT JOIN IndividualVertex AS StartIndividualVertex ON StartIndividualVertex.vertex = Edge.start
LEFT JOIN People AS StartPeople ON StartPeople.individual = StartIndividualVertex.individual
LEFT JOIN Entities AS StartEntities ON StartEntities.individual = StartIndividualVertex.individual
LEFT JOIN Word AS StartType ON StartType.id = StartIndividualVertex.type
 AND StartType.culture IS NULL
LEFT JOIN IndividualVertex AS StopIndividualVertex ON StopIndividualVertex.vertex = Edge.stop
LEFT JOIN People AS StopPeople ON StopPeople.individual = StopIndividualVertex.individual
LEFT JOIN Entities AS StopEntities ON StopEntities.individual = StopIndividualVertex.individual
LEFT JOIN Word AS StopType ON StopType.id = StopIndividualVertex.type
 AND StopType.culture IS NULL
;

--
-- View: Bills
--
CREATE VIEW Bills ( bill, type, date, supplier, supplierName, consignee, consigneeName, source, sourceType, parent, parentType ) AS
SELECT
 Bill.id AS bill,
 Type.value AS type,
 DATE(Bill.created) AS date,
 Bill.supplier,
 Supplier.name AS supplierName,
 Bill.consignee,
 Consignee.name AS consigneeName,
 Source.id AS source,
 SourceType.value AS sourceType,
 Parent.id AS parent,
 ParentType.value AS parentType
FROM Bill
JOIN I18NWord AS Type ON Type.id = Bill.type
JOIN Entities AS Supplier ON Supplier.individual = Bill.supplier
JOIN Entities AS Consignee ON Consignee.individual = Bill.consignee
LEFT JOIN Bill AS Source ON Source.id = Bill.source
LEFT JOIN I18NWord AS SourceType ON SourceType.id = Source.type
LEFT JOIN Bill AS Parent ON Parent.id = Bill.parent
LEFT JOIN I18NWord AS ParentType ON ParentType.id = Parent.type
;

--
-- View: LineItemsRaw
--
CREATE VIEW LineItemsRaw ( bill, billsource, billparent, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, version, parent, currentunitprice, unitprice, individualjob, job, schedule ) AS
SELECT CargoesRaw.bill,
 CargoesRaw.source AS billSource,
 CargoesRaw.parent AS billParent,
 Type.value AS typeName,
 CargoesRaw.type,
 COALESCE(Supplier.goesBy, Supplier.name) AS supplierName,
 CargoesRaw.supplier,
 COALESCE(Consignee.goesBy, Consignee.name) AS consigneeName,
 CargoesRaw.consignee,
 CargoesRaw.count,
 CargoesRaw.cargo AS line,
 Parts.name AS item,
 Parts.part,
 Parts.version,
 Parts.parent,
 COALESCE(SpecificPrice.price, DefaultPrice.price, AssemblyIndividualJobPrice.price) AS currentUnitPrice,
 COALESCE(JournalEntry.amount / CargoesRaw.count, FixedAssemblyIndividualJobPrice.price) AS unitPrice,
 IndividualJob.id AS individualJob,
 IndividualJob.job,
 IndividualJob.schedule
FROM CargoesRaw
JOIN I18NWord AS Type ON Type.id = CargoesRaw.type
JOIN Entities AS Supplier ON Supplier.individual = CargoesRaw.supplier
JOIN Entities AS Consignee ON Consignee.individual = CargoesRaw.consignee
JOIN Parts ON Parts.part = CargoesRaw.assembly
JOIN AssemblyCurrentPrice AS DefaultPrice ON DefaultPrice.assembly = CargoesRaw.assembly
 AND DefaultPrice.supplier IS NULL
LEFT JOIN AssemblyCurrentPrice AS SpecificPrice ON SpecificPrice.assembly = CargoesRaw.assembly
 AND SpecificPrice.supplier = CargoesRaw.supplier
LEFT JOIN JournalEntry ON JournalEntry.journal = CargoesRaw.journal
 AND JournalEntry.entry = CargoesRaw.entry
 AND JournalEntry.credit -- Income to bill.supplier
LEFT JOIN IndividualJob ON IndividualJob.individual = CargoesRaw.consignee
 AND IndividualJob.stop IS NULL
LEFT JOIN AssemblyIndividualJobPrice ON AssemblyIndividualJobPrice.assembly = CargoesRaw.assembly
 AND AssemblyIndividualJobPrice.individualJob = IndividualJob.id
LEFT JOIN IndividualJob AS FixedIndividualJob ON FixedIndividualJob.id = CargoesRaw.individualJob
LEFT JOIN AssemblyIndividualJobPrice AS FixedAssemblyIndividualJobPrice ON FixedAssemblyIndividualJobPrice.assembly = CargoesRaw.assembly
 AND FixedAssemblyIndividualJobPrice.individualJob =  FixedIndividualJob.id
;

--
-- View: LineItems
--
CREATE VIEW LineItems ( bill, billsource, billparent, typename, type, suppliername, supplier, consigneename, consignee, count, line, item, part, version, parent, currentUnitPrice, unitprice, totalPrice, outstanding, individualjob, job, schedule ) AS
SELECT bill,
 billsource,
 billparent,
 typeName,
 type,
 supplierName,
 supplier,
 consigneeName,
 consignee,
 SUM(LineItemsRaw.count) AS count,
 line,
 item,
 part,
 version,
 parent,
 currentUnitPrice,
 unitPrice,
 SUM(LineItemsRaw.count) * unitPrice AS totalPrice,
 CASE WHEN CargoStateSum.cargo IS NOT NULL THEN
  SUM(LineItemsRaw.count) - CargoStateSum.count
 ELSE
  SUM(LineItemsRaw.count)
 END AS outstanding,
 individualJob,
 job,
 schedule
FROM LineItemsRaw
LEFT JOIN (
 SELECT cargo, SUM(COALESCE(count, 1)) AS count
 FROM CargoState
 GROUP BY CargoState.cargo
) AS CargoStateSum ON CargoStateSum.cargo = line
GROUP BY
 bill,
 billsource,
 billparent,
 typeName,
 type,
 supplierName,
 supplier,
 consigneeName,
 consignee,
 line,
 item,
 part,
 version,
 parent,
 currentUnitPrice,
 unitPrice,
 individualJob,
 job,
 schedule,
 CargoStateSum.cargo,
 CargoStateSum.count
;

--
-- View: CAs
--
CREATE VIEW CAs ( id, parent, name, owner ) AS
SELECT CA.id,
CA.parent,
Entity.name,
COALESCE(Entities.name, People.fullname) AS owner
FROM CA
JOIN Entity ON Entity.id = CA.name
LEFT JOIN Entities ON Entities.individual = CA.owner
LEFT JOIN People ON People.individual = CA.owner
;

--
-- View: Certificates
--
CREATE VIEW Certificates ( id, type, isca, ca, parent, start, days, stop, cn, serial ) AS
SELECT Certificate.id,
 Type.value AS type,
 (CACertificate.ca IS NOT NULL) AS isca,
 CAPolicy.ca,
 CA.parent,
 start,
 Certificate.days,
 Start + Certificate.days * INTERVAL '1 day' AS stop,
 cn,
 Certificate.serial
FROM Certificate
JOIN I18NWord AS Type ON Type.id = Certificate.type
JOIN CAPolicy ON CAPolicy.id = Certificate.CAPolicy
JOIN CA ON CA.id = CAPolicy.ca
LEFT JOIN CACertificate ON CACertificate.certificate = Certificate.id   
;


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


-- New or updated procedures

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
 inUnit float,
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
 inUnit float,
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



SELECT SetSchemaVersion('Business', '0', '2', '8');
