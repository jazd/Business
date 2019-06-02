-- Load up month span table
INSERT INTO Month (id, month) VALUES (1, 1);
INSERT INTO Month (id, month) VALUES (2, 2);
INSERT INTO Month (id, month) VALUES (3, 3);
INSERT INTO Month (id, month) VALUES (4, 4);
INSERT INTO Month (id, month) VALUES (5, 5);
INSERT INTO Month (id, month) VALUES (6, 6);
INSERT INTO Month (id, month) VALUES (7, 7);
INSERT INTO Month (id, month) VALUES (8, 8);
INSERT INTO Month (id, month) VALUES (9, 9);
INSERT INTO Month (id, month) VALUES (10, 10);
INSERT INTO Month (id, month) VALUES (11, 11);
INSERT INTO Month (id, month) VALUES (12, 12);

-- Initial holiday periods
INSERT INTO PeriodName (period, name) VALUES (1,3);
INSERT INTO PeriodName (period, name) VALUES (2,4);
INSERT INTO PeriodName (period, name) VALUES (3,5);
INSERT INTO PeriodName (period, name) VALUES (4,6);
INSERT INTO PeriodName (period, name) VALUES (5,7);
INSERT INTO PeriodName (period, name) VALUES (6,8);
INSERT INTO PeriodName (period, name) VALUES (7,9);
INSERT INTO PeriodName (period, name) VALUES (8,10);
INSERT INTO PeriodName (period, name) VALUES (9,11);
INSERT INTO PeriodName (period, name) VALUES (10,12);
INSERT INTO PeriodName (period, name) VALUES (11,13);

-- Christmas Day
INSERT INTO MonthDay (id, month, day) VALUES (13,12,25);
INSERT INTO Period (id, span) VALUES (1, 13);
-- Thanksgiving Day, fourth Thursday in November
INSERT INTO Period (id, span) VALUES (2, 11);
INSERT INTO DayOfWeek (id, start, dayOfMonth) VALUES (14, 4, 4);
INSERT INTO Period (id, span) VALUES (2, 14);
-- Veterans Day
INSERT INTO MonthDay (id, month, day) VALUES (15, 11, 11);
INSERT INTO Period (id, span) VALUES (3, 15);
-- Memorial Day, last Monday of May
INSERT INTO Period (id, span) VALUES (4, 5);
INSERT INTO DayOfWeek (id, start, dayOfMonth) VALUES (16, 1, -1);
INSERT INTO Period (id, span) VALUES (4, 16);
-- New Years Day
INSERT INTO MonthDay (id, month, day) VALUES (17, 1, 1);
INSERT INTO Period (id, span) VALUES (5, 17);
-- Martin Luther King, Jr. Day, third Monday of January
INSERT INTO Period (id, span) VALUES (6, 1);
INSERT INTO DayOfWeek (id, start, dayOfMonth) VALUES (18, 1, 3);
INSERT INTO Period (id, span) VALUES (6, 18);
-- George Washington''s Birthday, third Monday of February
INSERT INTO Period (id, span) VALUES (7, 2);
INSERT INTO Period (id, span) VALUES (7, 18);
-- Independence Day
INSERT INTO MonthDay (id, month, day) VALUES (19, 7, 4);
INSERT INTO Period (id, span) VALUES (8, 19);
-- Labor Day, first Monday in September
INSERT INTO Period (id, span) VALUES (9, 9);
INSERT INTO DayOfWeek (id, start, dayOfMonth) VALUES (20, 1, 1);
INSERT INTO Period (id, span) VALUES (9, 20);
-- Columbus Day, second Monday in October
INSERT INTO Period (id, span) VALUES (10, 10);
INSERT INTO DayOfWeek (id, start, dayOfMonth) VALUES (21, 1, 2);
INSERT INTO Period (id, span) VALUES (10, 21);
-- Valentine''s Day
INSERT INTO MonthDay (id, month, day) VALUES (22, 2, 14);
INSERT INTO Period (id, span) VALUES (11, 22);
-- Black History Month, the whole month of February
INSERT INTO Period (id, span) VALUES (12, 2);

---------------
-- Times of day
-- Meals
-- https://en.wikipedia.org/wiki/Outline_of_meals#Types_of_meals,_in_the_order_served_throughout_the_day
INSERT INTO PeriodName (period, name) VALUES (13,GetSentence('Breakfast'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (23, '08:00', '10:00');
INSERT INTO Period (id, span) VALUES (13, 23);
INSERT INTO PeriodName (period, name) VALUES (14,GetSentence('Second breakfast'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (24, '10:00', '12:00');
INSERT INTO Period (id, span) VALUES (14, 24);
INSERT INTO PeriodName (period, name) VALUES (15,GetSentence('Brunch'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (25, '10:00', '14:00');
INSERT INTO Period (id, span) VALUES (15, 25);
INSERT INTO PeriodName (period, name) VALUES (16,GetSentence('Elevenses'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (26, '11:00', '11:30');
INSERT INTO Period (id, span) VALUES (16, 26);
INSERT INTO PeriodName (period, name) VALUES (17,GetSentence('Morning tea'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (27, '10:30', '11:30');
INSERT INTO Period (id, span) VALUES (17, 27);
INSERT INTO PeriodName (period, name) VALUES (18,GetSentence('Lunch'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (28, '12:00', '13:00');
INSERT INTO Period (id, span) VALUES (18, 28);
INSERT INTO PeriodName (period, name) VALUES (19,GetSentence('Tea'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (29, '15:30', '17:00');
INSERT INTO Period (id, span) VALUES (19, 29);
INSERT INTO PeriodName (period, name) VALUES (20,GetSentence('Linner'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (30, '14:00', '16:00');
INSERT INTO Period (id, span) VALUES (20, 30);
INSERT INTO PeriodName (period, name) VALUES (21,GetSentence('Supper'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (31, '19:00', '23:59');
INSERT INTO Period (id, span) VALUES (21, 31);
INSERT INTO PeriodName (period, name) VALUES (22,GetSentence('Dinner'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (32, '19:00', '21:00');
INSERT INTO Period (id, span) VALUES (22, 32);
INSERT INTO PeriodName (period, name) VALUES (23,GetSentence('Holiday Dinner'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (33, '16:00', '21:00');
INSERT INTO Period (id, span) VALUES (23, 33);
INSERT INTO PeriodName (period, name) VALUES (24,GetSentence('Midnight Snack'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (34, '23:00', '01:00');
INSERT INTO Period (id, span) VALUES (24, 34);
