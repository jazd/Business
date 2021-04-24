CREATE VIEW Versions AS
SELECT Version.id AS version, name.value AS name,
 major.value +
  COALESCE('.' + minor.value, '') +
  COALESCE('.' + patch.value, '')
 AS value,
 major.value AS major,
 minor.value AS minor,
 patch.value AS patch
FROM Version
LEFT JOIN Word AS name ON name.id = Version.name
 AND name.culture = 1033
LEFT JOIN Word AS major ON major.id = Version.major
 AND major.culture = 1033
LEFT JOIN Word AS minor ON minor.id = Version.minor
 AND minor.culture = 1033
LEFT JOIN Word AS patch ON patch.id = Version.patch
 AND patch.culture = 1033
;
GO

CREATE VIEW URL AS
SELECT id AS path, protocol, host,
 protocol +
 CASE WHEN secure = 1 THEN 's' ELSE '' END +
 '://' + host + '/' +
 COALESCE(value,'') +
 CASE WHEN get IS NULL
 THEN ''
 ELSE '?' + get
 END AS value,
 created
FROM Path
;
GO

IF OBJECT_ID('[File]', 'V') IS NOT NULL
 DROP VIEW [File]
GO
CREATE VIEW [File] AS
SELECT id AS path, protocol, host,
 protocol +
 ':///' +
 COALESCE(value,'') +
 CASE WHEN value IS NOT NULL
 THEN '/'
 ELSE ''
 END +
 COALESCE(get,'')
 AS value,
 '/' +
 COALESCE(value,'') +
 CASE WHEN value IS NOT NULL
 THEN '/'
 ELSE ''
 END +
 COALESCE(get,'')
 AS [file],
 COALESCE(get,'') AS name,
 created
FROM Path
;
GO

IF OBJECT_ID('Emails', 'V') IS NOT NULL
 DROP VIEW Emails
GO
CREATE VIEW Emails AS
SELECT id AS email, username, plus, host,
 username +
 COALESCE('+' + plus, '') +
 '@'+ host AS value
FROM Email
;
GO

IF OBJECT_ID('Entities', 'V') IS NOT NULL
 DROP VIEW Entities
GO
CREATE VIEW Entities AS
SELECT Individual.id AS individual,
 Individual.entity,
 COALESCE(goesBy.value, Entity.name) AS commonName,
 goesBy.value AS goesBy,
 Entity.name,
 CAST(Individual.birth AS date) AS formed,
 NULL AS location,
 Individual.death AS dissolved,
 NULL AS aged,
 Individual.created
FROM Individual
JOIN Entity ON Entity.id = Individual.entity
LEFT JOIN Given AS goesBy ON goesBy.id = Individual.goesBy
WHERE Individual.nameChange IS NULL
;
GO

IF OBJECT_ID('People', 'V') IS NOT NULL
 DROP VIEW People
GO
CREATE VIEW People AS
SELECT Individual.id AS individual,
 Name.id AS name,
 COALESCE(goesBy.value,Given.value,
 Family.value) AS goesBy,
 NULL AS birthday,
 NULL AS in_days,
 COALESCE(honorific.value,'') +
  CASE WHEN (honorific.value IS NOT NULL AND Given.value IS NULL AND middle.value IS NULL) THEN ' ' ELSE '' END +
  COALESCE(CASE WHEN (honorific.value IS NOT NULL) THEN ' ' ELSE '' END + Given.value,'') +
  COALESCE(CASE WHEN (Given.value IS NOT NULL) THEN ' ' ELSE '' END + middle.value,'') +
  CASE WHEN (Given.value IS NOT NULL AND middle.value IS NULL) THEN ' ' ELSE '' END +
  COALESCE(CASE WHEN (middle.value IS NOT NULL) THEN ' ' ELSE '' END  + Family.value,'') +
  COALESCE(CASE WHEN (Family.value IS NOT NULL) THEN ' ' ELSE '' END + suffix.value,'') +
  COALESCE(CASE WHEN (suffix.value IS NOT NULL) THEN ' ' ELSE '' END + post.value,'')
 AS fullName,
 Individual.prefix AS honorific,
 Name.given,
 Name.middle,
 Name.family,
 Individual.suffix,
 Individual.post,
 honorific.value AS honorificValue,
 Given.value AS GivenValue,
 middle.value AS middleValue,
 Family.value AS FamilyValue,
 suffix.value AS suffixValue,
 post.value AS postValue,
 birth,
 death,
 NULL AS aged,
 Individual.created
FROM Individual
JOIN Name ON Name.id = Individual.name
LEFT JOIN Given ON Given.id = Name.given
LEFT JOIN Given AS middle ON middle.id = Name.middle
LEFT JOIN Given AS goesBy ON goesBy.id = Individual.goesBy
LEFT JOIN Family ON Family.id = Name.family
LEFT JOIN Word AS honorific ON honorific.id = Individual.prefix
 AND honorific.culture = 1033
LEFT JOIN Word AS suffix ON suffix.id = Individual.suffix
 AND suffix.culture = 1033
LEFT JOIN Word AS post ON post.id = Individual.post
 AND post.culture = 1033
WHERE Individual.nameChange IS NULL
 OR Individual.nameChange > CURRENT_TIMESTAMP
;
GO
