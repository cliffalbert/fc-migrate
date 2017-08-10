# fc-migrate
Fiberchannel Zoning Migration from QLogic to Brocade

This is a tool to migrate existing qlogic zoning information towards a brocade switch.

It has been tested between a Qlogic Sanbox 5602 and a Brocade DCX-4S.

Currently has only support for 1 Zoneset and supports the orphaned zoneset.

./fc-migrate.pl <SOURCECONFIG> <DESTINATIONCONFIG>

SOURCECONFIG is a backupped configdata from the qlogic
