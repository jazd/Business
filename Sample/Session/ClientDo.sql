-- PostgreSQL

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

-- Could be used as a template to create an anonymous session creation/id retrieval function 
DO $$
DECLARE agent_string INTEGER;
DECLARE application_identifier INTEGER;
DECLARE application_version INTEGER;
DECLARE os_identifier INTEGER;
DECLARE os_version INTEGER;
DECLARE application_release INTEGER;
DECLARE os_release INTEGER;
BEGIN
-- Pre-insert a valid agent string
agent_string := (SELECT id FROM GetIdentityPhrase('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36') AS id);
INSERT INTO Sentence (id,value,length,culture) VALUES(1999999,'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36',105,NULL);

-- Pre-insert a valid Application
-- Chrome
application_identifier := (SELECT ident FROM GetIdentifier('Chrome') AS ident);
-- Linux
os_identifier := (SELECT ident FROM GetIdentifier('Linux') AS ident);

-- Pre-insert a valid version
-- 43.0.2357
application_version := (SELECT version FROM GetVersion('43','0','2357') AS version);
-- x86_64
os_version := (SELECT version FROM GetVersionName('x86_64') AS version);

-- Releases of applications
-- Chrome
application_release := (SELECT release FROM GetRelease(application_version, '130') AS release);

-- Linux
os_release := (SELECT release FROM GetRelease(os_version, '130') AS release);

-- Pre-insert a valid Agent (ApplicationRelease)
-- Chrome/43.0.2357.130
INSERT INTO ApplicationRelease (id,application,release) VALUES (9999, 9999, application_release);
-- Linux x86_64
INSERT INTO ApplicationRelease (id,application,release) VALUES (9998, 9998, os_release);
END $$;

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
