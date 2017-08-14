#!/usr/bin/perl -w

my $version = "0.1";

print "Qlogic Sanbox to Brocade DCX Zoning Migration\n";
print "Release $version\n";
print "(c) 2017 Unilogic B.V.\n\n";

if (!$ARGV[0] || !$ARGV[1]) {
	die "fc-migrate.pl <INPUT FILE> <OUTPUT FILE>\n";
};

# Source Tested on Sanbox 5602 Software Version: V7.4.0.16.0
# Destination Tested on Brocade DCX-4 Software Version V7.1

# Configuration Variables

my $fabric_name = "UNIFAP";

# Initialize Variables

my %wwnAlias;
my %zoneSetDB;
my @zoneDB;
my @zoneTypeDB;
my @zoneMemberDB;
my $debug = 0;

sub convertWWN {
   my ($wwn) = @_;
   if ($wwn =~ /^([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})([0-9a-z]{2})/) {
    $outputWWN = "$1:$2:$3:$4:$5:$6:$7:$8";
    return $outputWWN;
   };
   return "00:00:00:00:00:00:00";
} 

sub returnWWNorAlias {
   my ($WWNMember) = @_;
   my $applicable_alias = 0;
   if ($wwnAlias{$zoneMemberDB[$row][$column]}) {
	$applicable_alias = $wwnAlias{$zoneMemberDB[$row][$column]};
        $applicable_alias =~ s/-/_/g;
   } else {
	$applicable_alias = convertWWN($WWNMember);
   }
   return $applicable_alias;
}
   

   my $source_file = $ARGV[0];
   my $output_file = $ARGV[1];
   print " - Opening configuration file $source_file\n";
   open CONFIG_FILE, "<$source_file" or die "Could not open file '$source_file' $!";
   print " - Opening output file $output_file\n";
   open(my $outputhandle, '>', $output_file) or die "Could not open file '$output_file' $!";

   while (<CONFIG_FILE>) { 
	if ($_ =~ /^NAME=Default.Snmp.SysDescr,TYPE=STRING,VAL=(.*$)/) {
	   $sourcePlatform = $1;
	   print " - Migrating from $sourcePlatform\n";
        };
 	if ($_ =~ /^NAME=Global.Nicknames.NumberOfNicknames,TYPE=UINT,VAL=(\d+)/) {
 	   $NumberOfNicknames = $1;
	   print " - Total number of WWN Nicknames is $NumberOfNicknames\n";
        };
	if ($_ =~ /^NAME=Global.Nicknames.(\d+),TYPE=STRING,VAL=\[(\S+)\]\[(\w+)\]\[WWN\]\[(\d+)\]\[(\d+)\]/) {
           $nickNameId = $1;
	   $nickNameName = $2; 
	   $nickNameWWN = $3;
 	   #$nickNameSerial = $4; 
	   #$nickNameDigit = $5;
 	   if ($debug) { print " - WWN $nickNameId Host $nickNameName has WWN $nickNameWWN \n"; };
   	   $wwnAlias{$nickNameWWN} = $nickNameName;
	   $nickNameName =~ s/-/_/g; 
	   print $outputhandle "alicreate \"$nickNameName\", \"".convertWWN($nickNameWWN)."\" \n";
	};
	if ($_ =~ /^NAME=Global.Zoning.NumberOfZones,TYPE=UINT,VAL=(\d+)/) { 
	   $NumberOfZones = $1;
	   print " - Total number of Zones is $NumberOfZones (including orphaned zones)\n";
        };
	if ($_ =~ /^NAME=Global.Zoning.ZoneList.(\d+),TYPE=STRING,VAL=(\S+)/) {
	   $zoneId = $1;
	   $zoneName = $2;
	   if ($debug) { print " - Zone $zoneId is $zoneName \n"; };
	   $zoneDB[$zoneId] = $zoneName;
	}; 
	if ($_ =~ /^NAME=Global.Zoning.Zone.(\d+).ZoneType,TYPE=STRING,VAL=(\S+)/) {
	   $zoneTypeId = $1;
	   $zoneTypeType = $2;
	   if ($debug) { print " - Zone $zoneDB[$zoneTypeId] is $zoneTypeType Zoned\n"; };
	   $zoneTypeDB[$zoneTypeId] = $zoneTypeType;
	};
	if ($_ =~ /^NAME=Global.Zoning.Zone.(\d+).NumberOfZoneMembers,TYPE=UINT,VAL=(\d+)/) {
	   $zoneCountId = $1;
	   $zoneCountNum = $2;
	   if ($debug) { print " - Zone $zoneDB[$zoneCountId] has $zoneCountNum members\n"; }; 
	};
 	if ($_ =~ /^NAME=Global.Zoning.Zone.(\d+).ZoneMemberList.(\d+),TYPE=STRING,VAL=1(\S+)/) {	
	   $zoneMemberZone = $1;
	   $zoneMemberId = $2;
	   $zoneMemberWWN = $3;
	   if ($debug) { print " - Zone $zoneDB[$zoneMemberZone] Member $zoneMemberId has WWN ".$wwnAlias{$zoneMemberWWN}."($zoneMemberWWN)\n"; };
 	   push @{$zoneMemberDB[$zoneMemberZone]}, $zoneMemberWWN;
	};
	if ($_ =~ /^NAME=Global.Zoning.ZoneSet.(\d+).ZoneIndex.(\d+),TYPE=UINT,VAL=(\d+)/) {
 	   $zoneSetId = $1;
	   $zoneSetIndex = $2;
	   $zoneSetZoneId = $3;
	   if ($debug) { print " - ZoneSet $zoneSetId has $zoneSetZoneId on index $zoneSetIndex\n"; };
        }; 

        if ($_ =~ /^NAME=Global.Zoning.ZoneSet.(\d+).ZoneList.(\d+),TYPE=STRING,VAL=(\S+)/) {
	   $zoneSetListId = $1;
	   $zoneSetListListId = $2;
	   $zoneSetListListName = $3;
	   if ($debug) { print " - ZoneSet $zoneSetListId has $zoneSetListListName on $zoneSetListListId\n"; };
 	   $zoneSetDB{$zoneSetListListName} = $zoneSetListListId;
	};
   };
   print " - Generating Fabric Config $fabric_name\n";

   print " - Writing brocade zoning configuration to $output_file \n";

   my $fabric_created = 0;

   foreach $row (0..@zoneMemberDB-1) {
	if ($debug) { print "D: $zoneDB[$row] \n"; }
	if (defined $zoneSetDB{$zoneDB[$row]}) {
          $applicable_zone = $zoneDB[$row];
  	  $applicable_zone =~ s/-/_/g;
	  $command_output = "zonecreate \"$applicable_zone\",\"";
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
