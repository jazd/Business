#!/bin/sh
# The MIT License (MIT) Copyright (c) 2014-2015 Stephen A Jazdzewski

mkdir -p diagrams

ARGS="--gutter=50 --db=XML"

INDIVIDUAL="Given Family Name Individual Entity Word"
LISTS="Individual ListIndividual ListIndividualName Word"
ADDRESSES="Address Postal Country Location Area Timezone Sentence Word Culture"
PHONES="Phone Country Location Area Timezone Culture Word Sentence"

INDIVIDUAL_EMAIL="Individual IndividualEmail Email Word"
INDIVIDUAL_PATH="Individual IndividualPath Path Word"

SESSION="Session AgentString SessionToken SessionCredential Individual Name Entity IndividualSessionCreated Password Credential Site Part AssemblyApplicationRelease Application Release Path ApplicationRelease SiteApplicationRelease Version Email Location Area Timezone Culture Sentence Word"

ASSEMBLIES="AssemblyPart Part PartDescription AssemblyApplicationRelease ApplicationRelease Version Word Sentence Paragraph"

EVENTS="Period DateRange TimeOfDay DayOfWeek MonthDay Month PeriodName Sentence"

DAG="Edge VertexName Individual IndividualVertex Sentence"

ACCOUNTING="Word Sentence Individual LedgerName AccountName JournalName BookName IndividualLedger LedgerAccount LedgerJournal JournalAccount BookAccount Entry JournalEntry AssemblyApplicationRelease Credential"

INVENTORY="Word Sentence Individual Part AssemblyApplicationRelease Credential Period  ScheduleName JobName Entry JournalEntry IndividualAssemblyCost IndividualAssemblyCustomerPrice Schedule JobIndividual Bill Cargo CargoState"

# Include invalid refrences for display purposes only
cat schema.xml | sed '/invalid/ {s/<comments invalid="">//; s/<\/comments>//}' > schema.xml.invalid

scripts/extractTable.pl schema.xml.invalid $INDIVIDUAL >./zot.xml
sqlt-diagram --title "Individual People and Entity Events" $ARGS -c 2 -o diagrams/individual.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $LISTS >./zot.xml
sqlt-diagram --title "Lists of Individual People and Entities" $ARGS -c 2 -o diagrams/lists.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $PHONES >./zot.xml
sqlt-diagram --title "Phones" $ARGS -c 2 -o diagrams/phones.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $INDIVIDUAL_EMAIL >./zot.xml
sqlt-diagram --title "Individual Email" $ARGS -c 2 -o diagrams/individual_email.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $INDIVIDUAL_PATH >./zot.xml
sqlt-diagram --title "Individual URL" $ARGS -c 2 -o diagrams/individual_path.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $ADDRESSES >./zot.xml
sqlt-diagram --title "Addresses" $ARGS -c 3 -o diagrams/addresses.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $SESSION >./zot.xml
sqlt-diagram --title "Session" $ARGS -c 5 -o diagrams/web_session.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $ASSEMBLIES >./zot.xml
sqlt-diagram --title "Assemblies" $ARGS -c 3 -o diagrams/assemblies.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $EVENTS >./zot.xml
sqlt-diagram --title "Events" $ARGS -c 2 -o diagrams/events.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $ACCOUNTING >./zot.xml
sqlt-diagram --title "Double Entry Accounting" $ARGS -c 4 -o diagrams/accounting.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $INVENTORY >./zot.xml
sqlt-diagram --title "Inventory Movement" $ARGS -c 5 -o diagrams/inventory.png ./zot.xml

scripts/extractTable.pl schema.xml.invalid $DAG >./zot.xml
sqlt-diagram --title "Directed Acyclic Graph" $ARGS -c 3 -o diagrams/dag.png ./zot.xml

# Remove temporary files
rm zot.xml
rm schema.xml.invalid
