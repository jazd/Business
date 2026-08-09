-- Wiki / Static/3_Address.sql seed without GetAddress().
-- Requires Postal rows for 10504 and 20500 (GeoNames sample via PostalImportSQLite).

-- IBM Armonk (1 New Orchard Road, 10504-1716)
INSERT INTO Location (latitude, longitude, accuracy)
 SELECT 41.10509638465931, -73.71933460235596, 1
 WHERE NOT EXISTS (
  SELECT 1 FROM Location
  WHERE latitude = 41.10509638465931
    AND longitude = -73.71933460235596
    AND accuracy = 1
    AND parent IS NULL
 );

INSERT INTO Address (line1, postal, postalPlus, location)
 SELECT
  '1 New Orchard Road',
  p.id,
  '1716',
  (SELECT id FROM Location
   WHERE latitude = 41.10509638465931
     AND longitude = -73.71933460235596
     AND accuracy = 1
   ORDER BY id DESC LIMIT 1)
 FROM Postal p
 JOIN Country c ON c.id = p.country
 WHERE p.code = '10504' AND UPPER(c.code) = 'USA'
  AND NOT EXISTS (
   SELECT 1 FROM Address a
   WHERE UPPER(a.line1) = UPPER('1 New Orchard Road')
     AND a.postal = p.id
     AND a.postalPlus = '1716'
  )
 LIMIT 1;

-- White House (1600 Pennsylvania Avenue NW, 20500-0005)
INSERT INTO Location (latitude, longitude, accuracy)
 SELECT 38.897778, -77.036389, 2
 WHERE NOT EXISTS (
  SELECT 1 FROM Location
  WHERE latitude = 38.897778
    AND longitude = -77.036389
    AND accuracy = 2
    AND parent IS NULL
 );

INSERT INTO Address (line1, postal, postalPlus, location)
 SELECT
  '1600 Pennsylvania Avenue NW',
  p.id,
  '0005',
  (SELECT id FROM Location
   WHERE latitude = 38.897778
     AND longitude = -77.036389
     AND accuracy = 2
   ORDER BY id DESC LIMIT 1)
 FROM Postal p
 JOIN Country c ON c.id = p.country
 WHERE p.code = '20500' AND UPPER(c.code) = 'USA'
  AND NOT EXISTS (
   SELECT 1 FROM Address a
   WHERE UPPER(a.line1) = UPPER('1600 Pennsylvania Avenue NW')
     AND a.postal = p.id
     AND a.postalPlus = '0005'
  )
 LIMIT 1;
