-- Thank you. Sentence 80110 then word 80110 (subscription), argument 80111 (subscriptions).
-- Cultures: 1033 en-US, 1036 fr-FR, 1045 pl-PL, 2058 es-MX.
INSERT INTO Content (id, name) VALUES (10, 80130);
INSERT INTO ContentEdition (id, content) VALUES (10, 10);
INSERT INTO ContentElement (edition, sequence, sentence) VALUES (10, 1, 80110);
INSERT INTO ContentElement (edition, sequence, word, argument) VALUES (10, 2, 80110, 80111);

-- Notice. Heading, link, then an unsquashed lede and count, then the same
-- pair with squash space. Sentence cultures: 1033 en-US, 1036 fr-FR, 2058 es-MX.
INSERT INTO Format (id, name) VALUES (1, 80143);
INSERT INTO Format (id, name) VALUES (2, 80144);
INSERT INTO Format (id, name) VALUES (3, 80145);
INSERT INTO FormatAttribute (format, name, value) VALUES (1, 80120, 80121);
INSERT INTO FormatAttribute (format, name, value) VALUES (2, 80120, 80122);
INSERT INTO FormatAttribute (format, name, value) VALUES (3, 80120, 80123);
INSERT INTO Content (id, name) VALUES (11, 80142);
INSERT INTO ContentEdition (id, content) VALUES (11, 11);
INSERT INTO ContentElement (edition, sequence, sentence, format) VALUES (11, 1, 80140, 1);
INSERT INTO ContentElement (edition, sequence, format, name, type) VALUES (11, 2, 3, 80124, 80125);
INSERT INTO ContentElement (edition, sequence, sentence, format) VALUES (11, 3, 80141, 2);
INSERT INTO ContentElement (edition, sequence, name, type) VALUES (11, 4, 80126, 80127);
INSERT INTO ContentElement (edition, sequence, format, name, type, squash) VALUES (11, 5, 2, 80126, 80127, 80128);
INSERT INTO ContentElement (edition, sequence, sentence, format, squash) VALUES (11, 6, 80141, 2, 80128);
