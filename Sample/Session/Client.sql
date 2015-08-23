-- PostgreSQL
-- Pre-insert a valid agent string
INSERT INTO Sentence (id,value,length,culture) VALUES(1999999,'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36',105,NULL);
-- Pre-insert a valid Application
INSERT INTO Application (id,name)
SELECT 9999 AS id, Word.id  AS name
FROM Word
WHERE value = 'Chrome'
 AND culture IS NULL
;
-- Pre-insert a valid version

-- Insert the session record using the site's session id function
INSERT INTO Session (id) VALUES('63840346be345744139d5d8b70292ff2');
-- Associate a remote client and remote IP address to a session
INSERT INTO SessionCredential (session,agent,fromAddress)
SELECT '63840346be345744139d5d8b70292ff2' AS session, Sentence.id AS agent, '107.77.97.52' AS fromAddress
FROM Sentence
WHERE value = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36'
 AND culture IS NULL
;

