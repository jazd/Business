-- Client session example in two steps.
-- 1)   A client hits the server without a session token, so generate an anonymous session to track it going forward.
-- 1.a) Parse Client(Browser) Agent string.
-- 1.b) Insert the parsed Client Agent string, reffering URL and source IP address into an Anonymous Session.
--      The AgentString table will associate this string to its AssemblyApplicationRelease(agent) id.  As the name implies, the agent is an assembly(device) associated with and ApplicationRelease(os and client)
-- 2)   Client requests to create a user
-- 2.a) Assign a session token to the anonymous session
--      Session data, status and timeout is also stored in this record
-- 2.b) Client generates a valid password
-- 2.c) Create a user credential (account) associated with the new password
-- 2.d) Associate current session with new user credential

--
-- Step 1 for initial unknown server client access
-- 1.a) Parse Client(Browser) Agent string 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36'
-- 1.b) Insert the parsed Client Agent string, reffering URL and source IP address into an Anonymous Session.
SELECT AnonymousSession('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36',
'Chrome','43','0','2357','130','Linux',NULL,NULL,NULL,NULL,NULL,'Other',
0,'www.ibm.com',NULL,NULL,
'107.77.97.52') FROM DUAL;
--  anonymoussession 
-- ------------------
--                1  -- session id
-- AnonymousSession should be called on every anonymous page load to keep session alive and track the client

-- Step 2 for when session needs to be associated with a user. In this case, a new user(credential).
-- 2.a) Assign a session token to the anonymous session
INSERT INTO SessionToken (session, token, initialized, timeout, items) SELECT 1, 'BKrB9cYbZYcP1xKbKBOeXsAxDmoybyHn', 1, NULL, NULL FROM DUAL;
-- 2.b) Client generates a valid password
--      No Provider or Generator, so password is in the clear
INSERT INTO password (provider, generator, value) VALUES (NULL, NULL, '1234');
-- In this example, password.id is 1
-- 2.c) Create a user credential (account) associated with the new password
INSERT INTO credential (username, password, culture) VALUES ('helmet', 1, 1033);
-- 2.d) Associate current session with new user credential
--      (Token, siteId, agentStringId, credentialId, referringURLId, remoteAddr, locationId)
--      Adds record to SessionCredential
SELECT SetSession('BKrB9cYbZYcP1xKbKBOeXsAxDmoybyHn', NULL, 1000, 1, 10, '107.77.97.52', NULL) FROM DUAL;
-- SetSession should be called on every page load to keep session alive and track the client



