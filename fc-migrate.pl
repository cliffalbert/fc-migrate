#!/usr/bin/perl -w

use strict;

my $version = "0.2";

print "Qlogic Sanbox to Brocade DCX Zoning Migration\n";
print "Release $version\n";
print "(c) 2017 Unilogic B.V.\n\n";

if (!$ARGV[0] || !$ARGV[1]) {
	die "fc-migrate.pl <INPUT FILE> <OUTPUT FILE> (<CFG_NAME>)\n";
};

# Source Tested on Sanbox 5602 Software Version: V7.4.0.16.0
# Destination Tested on Brocade DCX-4 Software Version V7.1

# Configuration Variables

my $fabric_name = "MYBROCADECFG";

# Initialize Variables

my %wwnAlias;
my %zoneSetDB;
my @zoneDB;
my @zoneTypeDB;
my @zoneMemberDB;
my $debug = 0;

sub convertWWN {
   my ($wwn) = @_;
   my $outputWWN;
   if ($wwn =~ /^([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})/) {
    $outputWWN = "$1:$2:$3:$4:$5:$6:$7:$8";
    return $outputWWN;
   };
   return "00:00:00:00:00:00:00";
} 

sub returnWWNorAlias {
   my ($WWNMember) = @_;
   my $applicable_alias = 0;
   if ($wwnAlias{$WWNMember}) {
	$applicable_alias = $wwnAlias{$WWNMember};
        $applicable_alias =~ s/-/_/g;
   } else {
	$applicable_alias = convertWWN($WWNMember);
   }
   return $applicable_alias;
}
   

   my $source_file = $ARGV[0];
   my $output_file = $ARGV[1];
   if (defined $ARGV[2]) { $fabric_name = $ARGV[2]; };
   print " - Opening configuration file $source_file\n";
   open CONFIG_FILE, "<$source_file" or die "Could not open file '$source_file' $!";
   print " - Opening output file $output_file\n";
   open(my $outputhandle, '>', $output_file) or die "Could not open file '$output_file' $!";

   while (<CONFIG_FILE>) { 
	if ($_ =~ /^NAME=Default.Snmp.SysDescr,TYPE=STRING,VAL=(.*$)/) {
	   my $sourcePlatform = $1;
	   print " - Migrating from $sourcePlatform\n";
        };
 	if ($_ =~ /^NAME=Global.Nicknames.NumberOfNicknames,TYPE=UINT,VAL=(\d+)/) {
 	   my $NumberOfNicknames = $1;
	   print " - Total number of WWN Nicknames is $NumberOfNicknames\n";
        };
	if ($_ =~ /^NAME=Global.Nicknames.(\d+),TYPE=STRING,VAL=\[(\S+)\]\[(\w+)\]\[WWN\]\[(\d+)\]\[(\d+)\]/) {
           my $nickNameId = $1;
	   my $nickNameName = $2; 
	   my $nickNameWWN = $3;
 	   if ($debug) { print " - WWN $nickNameId Host $nickNameName has WWN $nickNameWWN \n"; };
   	   $wwnAlias{$nickNameWWN} = $nickNameName;
	   $nickNameName =~ s/-/_/g; 
	   print $outputhandle "alicreate \"$nickNameName\", \"".convertWWN($nickNameWWN)."\" \n";
	};
	if ($_ =~ /^NAME=Global.Zoning.NumberOfZones,TYPE=UINT,VAL=(\d+)/) { 
	   my $NumberOfZones = $1;
	   print " - Total number of Zones is $NumberOfZones (including orphaned zones)\n";
        };
	if ($_ =~ /^NAME=Global.Zoning.ZoneList.(\d+),TYPE=STRING,VAL=(\S+)/) {
	   my $zoneId = $1;
	   my $zoneName = $2;
	   if ($debug) { print " - Zone $zoneId is $zoneName \n"; };
	   $zoneDB[$zoneId] = $zoneName;
	}; 
	if ($_ =~ /^NAME=Global.Zoning.Zone.(\d+).ZoneType,TYPE=STRING,VAL=(\S+)/) {
	   my $zoneTypeId = $1;
	   my $zoneTypeType = $2;
	   if ($debug) { print " - Zone $zoneDB[$zoneTypeId] is $zoneTypeType Zoned\n"; };
	   $zoneTypeDB[$zoneTypeId] = $zoneTypeType;
	};
	if ($debug && $_ =~ /^NAME=Global.Zoning.Zone.(\d+).NumberOfZoneMembers,TYPE=UINT,VAL=(\d+)/) {
	   my $zoneCountId = $1;
	   my $zoneCountNum = $2;
	   print " - Zone $zoneDB[$zoneCountId] has $zoneCountNum members\n"; 
	};
 	if ($_ =~ /^NAME=Global.Zoning.Zone.(\d+).ZoneMemberList.(\d+),TYPE=STRING,VAL=1(\S+)/) {	
	   my $zoneMemberZone = $1;
	   my $zoneMemberId = $2;
	   my $zoneMemberWWN = $3;
	   if ($debug) { print " - Zone $zoneDB[$zoneMemberZone] Member $zoneMemberId has WWN ".$wwnAlias{$zoneMemberWWN}."($zoneMemberWWN)\n"; };
 	   push @{$zoneMemberDB[$zoneMemberZone]}, $zoneMemberWWN;
	};
	if ($debug && $_ =~ /^NAME=Global.Zoning.ZoneSet.(\d+).ZoneIndex.(\d+),TYPE=UINT,VAL=(\d+)/) {
 	   my $zoneSetId = $1;
	   my $zoneSetIndex = $2;
	   my $zoneSetZoneId = $3;
	   print " - ZoneSet $zoneSetId has $zoneSetZoneId on index $zoneSetIndex\n";
        }; 

        if ($_ =~ /^NAME=Global.Zoning.ZoneSet.(\d+).ZoneList.(\d+),TYPE=STRING,VAL=(\S+)/) {
	   my $zoneSetListId = $1;
	   my $zoneSetListListId = $2;
	   my $zoneSetListListName = $3;
	   if ($debug) { print " - ZoneSet $zoneSetListId has $zoneSetListListName on $zoneSetListListId\n"; };
 	   $zoneSetDB{$zoneSetListListName} = $zoneSetListListId;
	};
   };
   print " - Generating Fabric Config $fabric_name\n";

   print " - Writing brocade zoning configuration to $output_file \n";

   my $fabric_created = 0;

   my $row;
   foreach $row (0..@zoneMemberDB-1) {
	if ($debug) { print "D: $zoneDB[$row] \n"; }
	if (defined $zoneSetDB{$zoneDB[$row]}) {
          my $applicable_zone = $zoneDB[$row];
  	  my $command_output;
  	  $applicable_zone =~ s/-/_/g;
	  $command_output = "zonecreate \"$applicable_zone\",\"";
 	  my $column;
 	  foreach $column (0..@{$zoneMemberDB[$row]}-1) {
            $command_output .= " ".returnWWNorAlias($zoneMemberDB[$row][$column]).";";
 	    if ($debug) { print "Zone $zoneDB[$row] has member $wwnAlias{$zoneMemberDB[$row][$column]} ($zoneMemberDB[$row][$column])\n"; };
          };
	  $command_output =~ s/\;+$//;
	  print $outputhandle "$command_output\"\n";
  	  if ($fabric_created < 1) {
  	     print $outputhandle "cfgcreate \"$fabric_name\", \"$applicable_zone\"\n";
	     $fabric_created = 1;
          } else { 
 	     print $outputhandle "cfgadd \"$fabric_name\", \"$applicable_zone\"\n";
	  } 
	};
   };
   close $outputhandle;
