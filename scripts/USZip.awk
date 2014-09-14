# GeoNames Postal Code files www.geonames.org
# Conversion script
# Copyright (c) 2014 Stephen A Jazdzewski
BEGIN {
 FS = OFS = "\t";
 # $1 Country Code
 # $2 Postal Code
 # $3 Place name, City, Township
 # $4 State full
 # $5 State abbrivation
 # $6 County
 # $10 Lat
 # $11 Long
 # $12 Accuracy
}
{
	sub("US","USA",$1);  # Long ISO code
	sub(" County$","",$6); # Redundent
	sub(/\W\(.*/,"",$6); # Strip off " (CA)"
	print $1,$2,$3,$5,$4,$6,$10,$11,$12
}
END {
}
