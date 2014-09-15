# Take CSV and turn it into Procedure Calls PorgreSQL
# Copyright (c) 2014 Stephen A Jazdzewski
BEGIN {
 FS = OFS = "\t";
 # $1 Country Code
 # $2 Postal Code
 # $3 Place name, City, Township
 # $4 State abbrivation
 # $5 State full
 # $6 County
 # $7 Lat
 # $8 Long
 # $9 Accuracy
}
{
    sub(/\B/,"NULL",$9); # replace empty Accracy with NULL
    print "SELECT GetPostal('" $1 "','" $2 "','" $3  "','" $4 "','" $5 "','" $6 "'," $7 "," $8 "," $9 ");"
}
END {
}
