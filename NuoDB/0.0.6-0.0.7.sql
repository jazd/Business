-- NuoDB database schema version 0.0.6 to 0.0.7
--
-- Static/1_Sentence.sql
INSERT INTO Sentence (id,culture,value,length) VALUES(25,1033,'Midnight Snack',14);
-- Static/2_Event.sql
INSERT INTO PeriodName (period, name) VALUES (24,GetSentence('Midnight Snack'));
INSERT INTO TimeOfDay (id, start, stop) VALUES (34, '23:00', '01:00');
INSERT INTO Period (id, span) VALUES (24, 34);


-- VIEWs
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
  AND CAST(ClientNow() AS time) < stop
FROM Period
JOIN TimeOfDay ON TimeOfDay.id = Period.span
 AND TimeOfDay.start < TimeOfDay.stop
UNION
SELECT Period.id AS period,
 (CAST(ClientNow() AS time) >= start
   AND CAST(ClientNow() AS time) <= '23:59:59'
 ) OR (
  CAST(ClientNow() AS time) < stop
   AND CAST(ClientNow() AS time) >= '00:00:00'
 )
FROM Period
JOIN TimeOfDay ON TimeOfDay.id = Period.span
 AND TimeOfDay.start > TimeOfDay.stop
) AS timeperiod
GROUP BY period
;
