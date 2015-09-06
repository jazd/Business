-- PostgreSQL
-- Pre-insert a valid agent string
INSERT INTO Sentence (id,value,length,culture) VALUES(1999999,'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36',105,NULL);
-- Pre-insert a valid Application
-- Chrome
INSERT INTO Application (id,name)
SELECT 9999 AS id, Word.id  AS name
FROM Word
WHERE value = 'Chrome'
 AND culture IS NULL
;
-- Linux
INSERT INTO Application (id,name)
SELECT 9998 AS id, Word.id  AS name
FROM Word
WHERE value = 'Linux'
 AND culture IS NULL
;
-- Pre-insert a valid version
-- 43.0.2357
INSERT INTO Version (id,major,minor,patch)
SELECT 9999 AS id, Major.id AS major, Minor.id AS minor, Patch.id AS patch
FROM Word AS Major
JOIN Word AS Minor ON Minor.value = '0' AND Minor.culture IS NULL
JOIN Word AS Patch ON Patch.value = '2357' AND Patch.culture IS NULL
WHERE Major.value = '43' AND Major.culture IS NULL
;
-- x86_64
INSERT INTO Version (id,name)
SELECT 9998 AS id, Word.id AS name
FROM Word
WHERE Word.value = 'x86_64' AND Word.culture IS NULL
;
-- Releases of applications
-- Chrome
INSERT INTO Release (id,build,version)
SELECT 9999 AS id, Build.id AS build, 9999 AS version
FROM Word AS Build
WHERE Build.value = '130' AND Build.culture IS NULL
;
-- Linux
INSERT INTO Release (id,version) VALUES (9998,9998);
-- Pre-insert a valid Agent (ApplicationRelease)
-- Chrome/43.0.2357.130
INSERT INTO ApplicationRelease (id,application,release) VALUES (9999, 9999, 9999);
-- Linux x86_64
INSERT INTO ApplicationRelease (id,application,release) VALUES (9998, 9998, 9998);
--
-- Unknown agent device
INSERT INTO Part (id,name)
SELECT 9999 AS id, Word.id AS name
FROM Word
WHERE Word.value = 'Unknown' AND Word.culture IS NULL
;
-- Agent's Client and OS
INSERT INTO ClientOS (id, device, osrelease) VALUES (9999,9999,9998);
--
-- The parsed agent, Unknown device using OS Linux x86_64, Application Chrome/43.0.2357.130
INSERT INTO ClientOSApplication (id, clientOS, applicationRelease) VALUES (9999, 9999, 9999);
--
-- Insert the session record using the site's session id function
INSERT INTO Session (id) VALUES('63840346be345744139d5d8b70292ff2');
--
-- Associate a remote client and remote IP address to a session
INSERT INTO SessionCredential (session,agent,clientOSApplication,fromAddress)
SELECT '63840346be345744139d5d8b70292ff2' AS session, Sentence.id AS agent,
 9999 AS clientOSApplication, '107.77.97.52' AS fromAddress
FROM Sentence
WHERE value = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36'
 AND culture IS NULL
;
