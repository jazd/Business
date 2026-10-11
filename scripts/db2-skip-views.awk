# Drop CREATE VIEW statements. SQLFairy ends each view on its own semicolon line.
/^CREATE VIEW / { skip = 1; next }
skip && /^[[:space:]]*;[[:space:]]*$/ { skip = 0; next }
skip { next }
{ print }
