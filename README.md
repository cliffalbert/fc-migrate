# fc-migrate

## Fiberchannel Zoning Migration from QLogic to Brocade

This is a tool to migrate existing qlogic zoning information towards a brocade switch.

It has been tested between a Qlogic Sanbox 5602 and a Brocade DCX-4S.
Currently has only support for 1 Zoneset and supports the orphaned zoneset.

### Usage

```
./fc-migrate.pl <SOURCECONFIG> <DESTINATIONCONFIG> <CFG_NAME>
```

SOURCECONFIG is a backupped configdata from the qlogic

CFG_NAME is the name of the configuration on brocade where the zones should reside in. It is optional.

### Differences between Brocade and Qlogic

Brocade Zones do not accept - in their zone names, they are being converted to _

### TODO

- Multiple Zoneset Support
