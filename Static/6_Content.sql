-- Thank you. Sentence 80110 then word 80110 (subscription), argument 80111 (subscriptions).
-- Cultures: 1033 en-US, 1036 fr-FR, 1045 pl-PL, 2058 es-MX.
INSERT INTO Content (id, name) VALUES (10, 80130);
INSERT INTO ContentEdition (id, content) VALUES (10, 10);
INSERT INTO ContentElement (edition, sequence, sentence) VALUES (10, 1, 80110);
INSERT INTO ContentElement (edition, sequence, word, argument) VALUES (10, 2, 80110, 80111);
