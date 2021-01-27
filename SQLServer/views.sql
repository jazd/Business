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
