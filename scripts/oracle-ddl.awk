# Rewrite SQLFairy Oracle output so it loads on Oracle Database Free.
# Reserved identifiers are quoted. Part.serial is narrowed for its unique index.
# A repeated index or constraint name gets a numeric suffix.
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
  gsub(/DEFAULT NOW\(\)/, "DEFAULT SYSDATE")
  gsub(/timestamp without time zone/, "timestamp")
  gsub(/time without time zone/, "timestamp")
  gsub(/BLOB\(10\)/, "BLOB")
  sub(/^  start /, "  \"START\" ")
  sub(/^  session /, "  \"SESSION\" ")
  sub(/^  level /, "  \"LEVEL\" ")
  sub(/^  number /, "  \"NUMBER\" ")
  sub(/^  schema /, "  \"SCHEMA\" ")
  sub(/^  lock /, "  \"LOCK\" ")
  sub(/^  integer /, "  \"INTEGER\" ")
  sub(/^  float /, "  \"FLOAT\" ")
  sub(/^  count /, "  \"COUNT\" ")
  gsub(/FOREIGN KEY \(start\)/, "FOREIGN KEY (\"START\")")
  gsub(/FOREIGN KEY \(session\)/, "FOREIGN KEY (\"SESSION\")")
  gsub(/FOREIGN KEY \(lock\)/, "FOREIGN KEY (\"LOCK\")")
  gsub(/\(session,/, "(\"SESSION\",")
  gsub(/, session,/, ", \"SESSION\",")
  gsub(/, session\)/, ", \"SESSION\")")
  gsub(/\(session\)/, "(\"SESSION\")")
  gsub(/\(country, area, number\)/, "(country, area, \"NUMBER\")")
  sub(/port number\(1\)/, "port number(5)")
  sub(/^CREATE TABLE Session \(/, "CREATE TABLE \"SESSION\" (")
  sub(/^ALTER TABLE Session /, "ALTER TABLE \"SESSION\" ")
  sub(/BEFORE INSERT ON Session$/, "BEFORE INSERT ON \"SESSION\"")
  gsub(/ ON Session /, " ON \"SESSION\" ")
  gsub(/REFERENCES Session /, "REFERENCES \"SESSION\" ")
  if (inpart) sub(/serial varchar2\(4000\)/, "serial varchar2(800)")
  if (match($0, /^CREATE TABLE ([^ ]+) \(/, m)) curtable = m[1]
  if (curtable != "" && match($0, /PRIMARY KEY \(([^)]+)\)/, m)) pk[curtable] = normcols(m[1])
  if ($0 ~ /^\);/) curtable = ""
  if (match($0, /CREATE( UNIQUE)? INDEX [^ ]+ ON ([^ ]+) \(([^)]+)\)/, m)) {
    if (pk[m[2]] == normcols(m[3])) next
  }
  if (match($0, /CREATE( UNIQUE)? INDEX ([^ ]+)/, m)) {
    name = m[2]
    if (seen_idx[name]++) sub("INDEX " name " ", "INDEX " name "_" seen_idx[name] " ")
  }
  if (match($0, /ADD CONSTRAINT ([^ ]+) /, m)) {
    name = m[1]
    if (seen_con[name]++) sub("ADD CONSTRAINT " name " ", "ADD CONSTRAINT " name "_" seen_con[name] " ")
  }
  print
}
