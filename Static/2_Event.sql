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
