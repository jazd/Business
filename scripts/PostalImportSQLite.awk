# Take TSV from USZip.awk and emit pure SQLite seed SQL (no GetPostal).
# Columns: country zip city state_abbr state county lat long accuracy
BEGIN {
 FS = OFS = "\t"
}
function esc(s,   t) {
  t = s
  gsub(/'/, "''", t)
  return t
}
function sql_str(s) {
  if (s == "" || s == "NULL") return "NULL"
  return "'" esc(s) "'"
}
function sql_num(s) {
  if (s == "" || s == "NULL") return "NULL"
  return s
}
function ensure_word(w) {
  if (w == "" || w == "NULL") return
  # Find-or-insert Word (culture 1033); id=0 triggers SQLite auto id
  print "INSERT INTO Word (id, culture, value)"
  print " SELECT 0, 1033, " sql_str(w)
  print " WHERE NOT EXISTS ("
  print "  SELECT 1 FROM Word WHERE culture = 1033 AND UPPER(value) = UPPER(" sql_str(w) ")"
  print " );"
}
{
  country = $1
  zip = $2
  city = $3
  state_abbr = $4
  state = $5
  county = $6
  lat = $7
  long = $8
  acc = $9
  if (acc == "") acc = "NULL"

  ensure_word(city)
  ensure_word(state_abbr)
  ensure_word(state)
  ensure_word(county)

  # Location for this lat/long/accuracy (when coordinates present)
  if (lat != "" && long != "") {
    print "INSERT INTO Location (latitude, longitude, accuracy)"
    print " SELECT " lat ", " long ", " sql_num(acc)
    print " WHERE NOT EXISTS ("
    print "  SELECT 1 FROM Location"
    print "  WHERE parent IS NULL AND marquee IS NULL"
    print "   AND latitude = " lat " AND longitude = " long
    print "   AND ((accuracy = " sql_num(acc) ") OR (accuracy IS NULL AND " sql_num(acc) " IS NULL))"
    print "   AND level = 1 AND altitudeAboveSeaLevel IS NULL AND area IS NULL"
    print " );"
  }

  print "INSERT INTO Postal (country, code, state, stateAbbreviation, county, city, location)"
  print " SELECT c.id, " sql_str(zip) ","
  print "  (SELECT id FROM Word WHERE culture = 1033 AND UPPER(value) = UPPER(" sql_str(state) ") LIMIT 1),"
  print "  (SELECT id FROM Word WHERE culture = 1033 AND UPPER(value) = UPPER(" sql_str(state_abbr) ") LIMIT 1),"
  if (county != "") {
    print "  (SELECT id FROM Word WHERE culture = 1033 AND UPPER(value) = UPPER(" sql_str(county) ") LIMIT 1),"
  } else {
    print "  NULL,"
  }
  print "  (SELECT id FROM Word WHERE culture = 1033 AND UPPER(value) = UPPER(" sql_str(city) ") LIMIT 1),"
  if (lat != "" && long != "") {
    print "  (SELECT id FROM Location"
    print "   WHERE parent IS NULL AND marquee IS NULL"
    print "    AND latitude = " lat " AND longitude = " long
    print "    AND ((accuracy = " sql_num(acc) ") OR (accuracy IS NULL AND " sql_num(acc) " IS NULL))"
    print "    AND level = 1 AND altitudeAboveSeaLevel IS NULL AND area IS NULL"
    print "   LIMIT 1)"
  } else {
    print "  NULL"
  }
  print " FROM Country c"
  print " WHERE UPPER(c.code) = UPPER(" sql_str(country) ")"
  print "  AND NOT EXISTS ("
  print "   SELECT 1 FROM Postal p"
  print "   WHERE p.country = c.id AND UPPER(p.code) = UPPER(" sql_str(zip) ")"
  if (lat != "" && long != "") {
    print "    AND p.location = ("
    print "     SELECT id FROM Location"
    print "     WHERE latitude = " lat " AND longitude = " long
    print "      AND ((accuracy = " sql_num(acc) ") OR (accuracy IS NULL AND " sql_num(acc) " IS NULL))"
    print "     LIMIT 1)"
  } else {
    print "    AND p.location IS NULL"
  }
  print "  );"
  print ""
}
