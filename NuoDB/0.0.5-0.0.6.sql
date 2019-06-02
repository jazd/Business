-- NuoDB database schema version 0.0.5 to 0.0.6
--
SET DELIMITER @
CREATE OR REPLACE FUNCTION age (
 asOf DATE,
 start DATE
) RETURNS STRING DETERMINISTIC AS
 RETURN (
  SELECT CAST(DATEDIFF(YEAR, start, asOf) AS STRING) || ' years' FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION birthday (
 birth DATE,
 asOf DATE
) RETURNS STRING DETERMINISTIC AS
 RETURN (
  SELECT
  CASE WHEN extract(month FROM birth) < extract(month FROM asOf) THEN
    (extract(year FROM asOf) + 1) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
  ELSE
   CASE WHEN extract(month FROM birth) = extract(month FROM asOf)
     AND extract(day FROM birth) < extract(day FROM asOf) THEN
    (extract(year FROM asOf) + 1) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
   ELSE
    extract(year FROM asOf) || '-' ||  extract(month FROM birth) || '-' ||  extract(day FROM birth)
   END
  END AS birthday
  FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION days_until_birthday (
 birth DATE,
 asOf DATE
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
  SELECT DATEDIFF(DAY, asOf, birthday(birth)) FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION ClientCulture (
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
 SELECT 1033
 FROM Dual
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION GetInterval (
 interval_value STRING
) RETURNS INTEGER DETERMINISTIC AS
 RETURN (
  SELECT datediff(SECOND, '1970-01-01 ' || interval_value, '1970-01-01') FROM DUAL
 );
END_FUNCTION;
@
SET DELIMITER ;

SET DELIMITER @
CREATE OR REPLACE FUNCTION Make_Date (
 inYear INTEGER,
 inMonth INTEGER,
 inDay INTEGER
) RETURNS DATE DETERMINISTIC AS
 RETURN DATE(inYear || '-' || inMonth || '-' || inDay);
END_FUNCTION;
@
SET DELIMITER ;

-- TimePeriod View
CREATE OR REPLACE VIEW TimePeriod AS
SELECT period, MIN(open) AS open
FROM (
SELECT Period.id AS period,
 CAST(ClientNow() AS date) > make_date(CAST(extract(year FROM ClientNow()) AS integer),MonthDay.month, MonthDay.day) -1 AND
 CAST(ClientNow() AS date) <= make_date(CAST(extract(year FROM ClientNow()) AS integer),MonthDay.month, MonthDay.day) AS open
FROM Period
JOIN MonthDay ON MonthDay.id = Period.span
 AND MonthDay.weekOfMonth IS NULL
UNION
SELECT Period.id AS period,
 Month.month = extract(month FROM ClientNow())
FROM Period
JOIN Month ON Month.id = Period.span
 AND Month.year IS NULL
UNION
SELECT Period.id AS period,
 CAST(ClientNow() AS date) = (
  make_date(CAST(extract(year FROM ClientNow()) AS integer),CAST(extract(month FROM ClientNow()) AS integer), 1) + 7 * (DayOfWeek.start - 1) +
  CAST((7 + DayOfWeek.dayOfMonth - (dayofweek(
    make_date(CAST(extract(year FROM ClientNow()) AS integer),CAST(extract(month FROM ClientNow()) AS integer), 1) + 7 * (DayOfWeek.start - 1)
   ) -1)
  ) AS integer) %7
 )
FROM Period
JOIN DayOfWeek ON DayOfWeek.id = Period.span
 AND DayOfWeek.stop IS NULL
 AND DayOfWeek.dayOfMonth > 0
UNION
SELECT Period.id AS period,
 CAST(ClientNow() AS time) >= start
  AND CAST(ClientNow() AS time) <= stop
FROM Period
JOIN TimeOfDay ON TimeOfDay.id = Period.span
) AS timeperiod
GROUP BY period
  ;

-- MaxSpan View
CREATE VIEW MaxSpan AS
SELECT MAX(id) AS id FROM (
 SELECT coalesce(MAX(id), 0) AS id FROM DateRange
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM TimeOfDay
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM DayOfWeek
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM MonthDay
 UNION
 SELECT COALESCE(MAX(id), 0) AS id FROM Month
) AS MaxSpan
  ;

-- Static records for tests
-- Static/1_Sentence.sql
INSERT INTO Sentence (id,culture,value,length) VALUES(14,1033,'Breakfast',9);
INSERT INTO Sentence (id,culture,value,length) VALUES(15,1033,'Second breakfast',16);
INSERT INTO Sentence (id,culture,value,length) VALUES(16,1033,'Brunch',6);
INSERT INTO Sentence (id,culture,value,length) VALUES(17,1033,'Elevenses',9);
INSERT INTO Sentence (id,culture,value,length) VALUES(18,1033,'Morning tea',11);
INSERT INTO Sentence (id,culture,value,length) VALUES(19,1033,'Lunch',5);
INSERT INTO Sentence (id,culture,value,length) VALUES(20,1033,'Tea',3);
INSERT INTO Sentence (id,culture,value,length) VALUES(21,1033,'Linner',6);
INSERT INTO Sentence (id,culture,value,length) VALUES(22,1033,'Supper',6);
INSERT INTO Sentence (id,culture,value,length) VALUES(23,1033,'Dinner',6);
INSERT INTO Sentence (id,culture,value,length) VALUES(24,1033,'Holiday Dinner',14);
-- Static/2_Event.sql
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
