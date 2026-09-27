-- Thank-you body loaded by Static/6_Content.sql (content id 10).
-- Element 1 is sentence 80110. Element 2 is word 80110 with argument subscriptions (80111).
-- Cultures: en-US 1033, fr-FR 1036, pl-PL 1045, es-MX 2058.

SELECT culture, name
FROM ContentCultures
WHERE content = 10
ORDER BY culture;

-- Count 1 and 2 in the client culture. Set inject_culture to 1036, 1045, or 2058 to switch.
SELECT PluralWord(80110, 1) AS one, PluralWord(80110, 2) AS two;
