#!/bin/sh
# The MIT License (MIT) Copyright (c) 2014 Stephen A Jazdzewski

mkdir -p diagrams

ARGS="--gutter=50 --db=XML"

INDIVIDUAL="Given Family Name Individual Entity Word"
LISTS="Individual IndividualList IndividualListName Word"

# Include invalid refrences for display purposes only
cat schema.xml | sed '/invalid/ {s/<comments invalid="">//; s/<\/comments>//}' > schema.xml.invalid

scripts/extractTable.pl schema.xml.invalid $INDIVIDUAL >./zot.xml
sqlt-diagram --title "Individual People and Entity Events" $ARGS -c 2 -o diagrams/individual.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $LISTS >./zot.xml
sqlt-diagram --title "Lists of Individual People and Entities" $ARGS -c 2 -o diagrams/lists.png ./zot.xml

# Remove temporary files
rm zot.xml
rm schema.xml.invalid
