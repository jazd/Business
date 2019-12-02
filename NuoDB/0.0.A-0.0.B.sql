-- NuoDB database schema version 0.0.A to 0.0.B
-- Allow for addresses without county or abbreviated states
ALTER TABLE Postal CHANGE COLUMN stateAbbreviation stateAbbreviation INTEGER NULL;
ALTER TABLE Postal CHANGE COLUMN county county INTEGER NULL;

-- IndividualAddress constraints and index
ALTER TABLE Address ALTER COLUMN id PRIMARY KEY;
ALTER TABLE IndividualAddress ADD CONSTRAINT individualAddress_address FOREIGN KEY (address) REFERENCES Address(id);
CREATE INDEX individualAddress_individual_stop ON IndividualAddress (individual, stop);

CREATE OR REPLACE VIEW Addresses AS
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
JOIN Word AS City ON City.id = Postal.city
 AND City.culture = ClientCulture()
JOIN Word AS State ON State.id = Postal.state
 AND State.culture =  ClientCulture()
LEFT JOIN Word AS StateAbbr ON StateAbbr.id = Postal.stateAbbreviation
 AND StateAbbr. culture =  ClientCulture()
LEFT JOIN Location AS AddressLocation On AddressLocation.id = Address.location
LEFT JOIN Location AS PostalLocation ON PostalLocation.id = Postal.location
LEFT JOIN Location AS CountryLocation ON CountryLocation.id = Country.location
;
