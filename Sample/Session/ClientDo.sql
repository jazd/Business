-- PostgreSQL
-- Could be used as a template to create an anonymous session creation/id retrieval function 
DO $$
DECLARE agent_string INTEGER;
DECLARE application_id INTEGER;
DECLARE application_version INTEGER;
DECLARE os_id INTEGER;
DECLARE os_version INTEGER;
DECLARE application_release INTEGER;
DECLARE os_release INTEGER;
DECLARE application_release_id INTEGER;
DECLARE os_release_id INTEGER;
DECLARE device INTEGER;
DECLARE device_os INTEGER;
DECLARE device_agent INTEGER;
DECLARE new_session VARCHAR;
BEGIN
-- Pre-insert a valid agent string
agent_string := (SELECT id FROM GetIdentityPhrase('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36') AS id);

-- Pre-insert a valid Application
-- Chrome
application_id := (SELECT application FROM GetApplication('Chrome') AS application);
-- Linux
os_id := (SELECT os FROM GetApplication('Linux') AS os);

-- Pre-insert a valid version
-- 43.0.2357
application_version := (SELECT version FROM GetVersion('43','0','2357') AS version);
-- x86_64
os_version := (SELECT version FROM GetVersionName('x86_64') AS version);

-- Releases of applications
-- Chrome
application_release := (SELECT release FROM GetRelease(application_version, '130') AS release);
-- Linux
os_release := (SELECT release FROM GetRelease(os_version) AS release);

-- Pre-insert a valid Agent (ApplicationRelease)
-- Chrome/43.0.2357.130
application_release_id := (SELECT id FROM GetApplicationRelease(application_id, application_release) AS id);
-- Linux x86_64
os_release_id := (SELECT id FROM GetApplicationRelease(os_id, os_release) AS id);

--
-- Unknown agent device
device := (SELECT id FROM GetPart('Unknown') AS id);

-- Agent's Client and OS
-- A client device and its operating system. Change to AssemblyApplicationRelease
device_os = (SELECT id FROM GetAssemblyApplicationRelease(device,os_release_id) AS id);
--
-- Information A client device and operating system and the application it is running.
-- AKA user agent. http://www.useragentstring.com/pages/Browserlist/  Change to AssemblyApplicationRelease
-- The parsed agent, Unknown device using OS Linux x86_64, Application Chrome/43.0.2357.130
device_agent = (SELECT id FROM GetAssemblyApplicationRelease(device,application_release_id,device_os) AS id);

--
-- Insert the session record using the site's session id function
new_session = (SELECT session FROM RandomString(32) AS session);
INSERT INTO Session (id) VALUES(new_session);

--
-- Associate a remote client and remote IP address to a session
INSERT INTO SessionCredential (session,agentString,agent,fromAddress)
SELECT new_session AS session, agent_string AS agentString,
 device_agent AS agent, '107.77.97.52' AS fromAddress
;

END $$;

