#!/usr/bin/env sh
# The MIT License (MIT) Copyright (c) 2014-2015 Stephen A Jazdzewski
# Podman can be used if perl is not installed with Twig
# e.g.
# podman run jazd/sqlt:dev perl scripts/extractTable.pl schema.xml Version
# Generating graphics takes a little more. build jazd/sqlt-diagram:dev for that
# podman build -t jazd/sqlt-diagram:dev -f Containerfile.sqlt-diagram .
# e.g.
# podman run -v $(pwd):/app jazd/sqlt-diagram:dev sqlt-diagram --title "All" --gutter=50 --db=XML -o all.png schema.xml

if [ -f /usr/local/bin/sqlt-diagram ]
then
	SQLTDIAGRAM=/usr/local/bin/sqlt-diagram
	EXTRACTTABLE=scripts/extractTable.pl
else
	podman build -t jazd/sqlt:dev -f Containerfile.sqlt .
	podman build -t jazd/sqlt-diagram:dev -f Containerfile.sqlt-diagram .
	SQLTDIAGRAM="podman run -v $(pwd):/app:Z --userns=keep-id jazd/sqlt-diagram:dev sqlt-diagram"
	EXTRACTTABLE="podman run -v $(pwd):/app:Z --userns=keep-id jazd/sqlt-diagram:dev scripts/extractTable.pl"
fi

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

ACCOUNTING="Word Sentence Individual LedgerName AccountName JournalName BookName IndividualLedger IndividualAccount LedgerAccount LedgerJournal JournalAccount BookAccount Entry JournalEntry AssemblyApplicationRelease Credential"

INVENTORY="Word Sentence Part AssemblyApplicationRelease PeriodName  ScheduleName JobName Entry JournalEntry IndividualAssemblyCost IndividualAssemblyCustomerPrice Schedule IndividualJob AssemblyIndividualJobPrice  Bill Cargo CargoState AccountName"

# Include invalid refrences for display purposes only
cat schema.xml | sed '/invalid/ {s/<comments invalid="">//; s/<\/comments>//}' > schema.xml.invalid

${EXTRACTTABLE} schema.xml.invalid $INDIVIDUAL >./zot.xml
${SQLTDIAGRAM} --title "Individual People and Entity Events" $ARGS -c 2 -o diagrams/individual.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $LISTS >./zot.xml
${SQLTDIAGRAM} --title "Lists of Individual People and Entities" $ARGS -c 2 -o diagrams/lists.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $PHONES >./zot.xml
${SQLTDIAGRAM} --title "Phones" $ARGS -c 2 -o diagrams/phones.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $INDIVIDUAL_EMAIL >./zot.xml
${SQLTDIAGRAM} --title "Individual Email" $ARGS -c 2 -o diagrams/individual_email.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $INDIVIDUAL_PATH >./zot.xml
${SQLTDIAGRAM} --title "Individual URL" $ARGS -c 2 -o diagrams/individual_path.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $ADDRESSES >./zot.xml
${SQLTDIAGRAM} --title "Addresses" $ARGS -c 3 -o diagrams/addresses.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $SESSION >./zot.xml
${SQLTDIAGRAM} --title "Session" $ARGS -c 5 -o diagrams/web_session.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $ASSEMBLIES >./zot.xml
${SQLTDIAGRAM} --title "Assemblies" $ARGS -c 3 -o diagrams/assemblies.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $EVENTS >./zot.xml
${SQLTDIAGRAM} --title "Events" $ARGS -c 2 -o diagrams/events.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $ACCOUNTING >./zot.xml
${SQLTDIAGRAM} --title "Double Entry Accounting" $ARGS -c 5 -o diagrams/accounting.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $INVENTORY >./zot.xml
${SQLTDIAGRAM} --title "Inventory Movement" $ARGS -c 5 -o diagrams/inventory.png ./zot.xml

${EXTRACTTABLE} schema.xml.invalid $DAG >./zot.xml
${SQLTDIAGRAM} --title "Directed Acyclic Graph" $ARGS -c 3 -o diagrams/dag.png ./zot.xml

# Remove temporary files
rm zot.xml
rm schema.xml.invalid
