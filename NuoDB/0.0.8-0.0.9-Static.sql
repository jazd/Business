-- Static/0_Culture.sql
-- es-MX       Spanish - Mexico        0x080A
INSERT INTO Culture (code, name) VALUES (2058,'es-MX');

-- Static/1_Sentence.sql
INSERT INTO Sentence (id,culture,value,length) VALUES(26,1033,'Black History Month',19);
INSERT INTO Sentence (id,culture,value,length) VALUES(27,1033,'5th of May',10);
INSERT INTO Sentence (id,culture,value,length) VALUES(27,2058,'Cinco de Mayo',13);
INSERT INTO Sentence (id,culture,value,length) VALUES(28,1033,'Day of the Taco',15);
INSERT INTO Sentence (id,culture,value,length) VALUES(28,2058,'Día del Taco',12);
INSERT INTO Sentence (id,culture,value,length) VALUES(29,1033,'National Taco Day',17);

-- Static/2_Event.sql
-- Fix Black History Month, the whole month of February
INSERT INTO PeriodName (period, name) VALUES (12, 26);
-- Other days
-- Cinco de Mayo
INSERT INTO PeriodName (period, name) VALUES (25, 27);
INSERT INTO MonthDay (id, month, day) VALUES (35, 5, 5);
INSERT INTO Period (id, span) VALUES (25, 35);
-- International Taco Day
INSERT INTO PeriodName (period, name) VALUES (26, 28);
INSERT INTO MonthDay (id, month, day) VALUES (36, 3, 31);
INSERT INTO Period (id, span) VALUES (26, 36);
-- National Taco Day
INSERT INTO PeriodName (period, name) VALUES (27, 29);
INSERT INTO MonthDay (id, month, day) VALUES (37, 10, 4);
INSERT INTO Period (id, span) VALUES (27, 37);
