# Rewrite SQLFairy DB2 output so it loads on Db2 LUW.
# VARCHAR(0) is not a length. Part.serial stays short enough for its unique index.
# An index that repeats the primary key column list is omitted.
function normcols(s,    t) {
  t = s
  gsub(/[ \t]/, "", t)
  return toupper(t)
}
BEGIN { inpart = 0; curtable = "" }
/^CREATE TABLE Part \(/ { inpart = 1 }
inpart && /^\)/ { inpart = 0 }
{
  gsub(/CREATE UNIQUEINDEX/, "CREATE UNIQUE INDEX")
  gsub(/TIMESTAMP WITHOUT TIME ZONE/, "TIMESTAMP")
  gsub(/TIME WITHOUT TIME ZONE/, "TIME")
  gsub(/DEFAULT false/, "DEFAULT 0")
  if (inpart) sub(/serial VARCHAR\(0\)/, "serial VARCHAR(800)")
  gsub(/VARCHAR\(0\)/, "VARCHAR(32672)")
  if (match($0, /^CREATE TABLE ([^ ]+) \(/, m)) curtable = m[1]
  if (curtable != "" && match($0, /PRIMARY KEY \(([^)]+)\)/, m)) pk[curtable] = normcols(m[1])
  if ($0 ~ /^\);/) curtable = ""
  if (match($0, /CREATE( UNIQUE)? INDEX [^ ]+ ON ([^ ]+) \( ([^)]+) \)/, m)) {
    if (pk[m[2]] == normcols(m[3])) next
  }
  print
}
