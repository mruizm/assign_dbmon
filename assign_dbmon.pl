#!/usr/bin/perl

##########################################################################################################
#Script that assigns a managed node to dbmon solution based on the db type specified and os type
#discovered while doing opcnode -list_nodes node_list=<manade_node>
#Parms:
#   -node_name|n <nodename>:    <nodename> managed node
#   -list <node_list>:          <node_list> input list of managed nodes
#   -db_type|d <db>:            <db> type of database [inf|sql|ora|pro|syb|]
#                               inf: Informix
#                               sql: MSSQL
#                               ora: Oracle
#                               pro: Progress
#                               syb: Sybase
##########################################################################################################
use strict;
use warnings;
use Getopt::Long;

#Ini script options
my $nodename;
my $nodename_mach_type;
my $nodelist;
my $db_type;
my $read_node;
my @node_or_list;
my @dbmon_ng_to_ch;
my $datetime_stamp_log;

#Init of script working paths
my $assign_dbmon_dir = '/var/opt/OpC_local/ASSIGN_DBMON';
my $assign_dbmon_log_dir = $assign_dbmon_dir.'/log';
my $assign_dbmon_tmp_dir = $assign_dbmon_dir.'/tmp';
chomp(my $datetime_stamp = `date "+%m%d%Y_%H%M%S"`);
my $assign_dbmon_log = $assign_dbmon_log_dir.'/assign_dbmon.'.$datetime_stamp.'.log';

#dbmon nodegroups
my @dbmon_nodegroups_inf = qw/A_DBMON_INFORMIX_MONITORING A_DBMON_INFORMIX_REPORTING/;
my @dbmon_nodegroups_sql = qw/A_DBMON_MSSQL_MONITORING A_DBMON_MSSQL_REPORTING/;
my @dbmon_nodegroups_mysql = qw/A_DBMON_MYSQL_UX_MONITORING A_DBMON_MYSQL_UX_REPORTING A_DBMON_MYSQL_WIN_MONITORING A_DBMON_MYSQL_WIN_REPORTING/;
my @dbmon_nodegroups_ora = qw/A_DBMON_ORACLE_UX_MONITORING A_DBMON_ORACLE_UX_REPORTING A_DBMON_ORACLE_WIN_MONITORING A_DBMON_ORACLE_WIN_REPORTING/;
my @dbmon_nodegroups_pro = qw/A_DBMON_PROGRESS_UX_MONITORING A_DBMON_PROGRESS_UX_REPORTING A_DBMON_PROGRESS_WIN_MONITORING A_DBMON_PROGRESS_WIN_REPORTING/;
my @dbmon_nodegroups_syb = qw/A_DBMON_SYBASE_UX_MONITORING A_DBMON_SYBASE_UX_REPORTING A_DBMON_SYBASE_WIN_MONITORING A_DBMON_SYBASE_WIN_REPORTING/;

#Create needed directories
system("mkdir -p $assign_dbmon_dir") if (!-d $assign_dbmon_dir);
system("mkdir -p $assign_dbmon_log_dir") if (!-d $assign_dbmon_log_dir);

#Def of script options
GetOptions( 'node_name|n=s' => \$nodename,
            'node_list|l=s' => \$nodelist,
            'db_type|d=s' => \$db_type);

#When both options are defined exit script
if ($nodename && $nodelist)
{
  print "\nError: Can't use both --node_name|-n and --node_list|-l parameters!\n";
  print "\n";
  exit 0;
}

#To validate that mandatory parameters are defined
if((!$nodename || !$nodelist) && !$db_type)
{
  print "\nError: A mandatory parameter is missing!\n";
  print "\nUsage: perl assign_dbmon.pl [--node_name|-n <nodename>] | [--node_list|-l <nodelist>] --db_type|-d <db>\n";
  print "<db>: inf|sql|mysql|ora|pro|syb\n";
  print "\n";
  exit 0;
}

#To validate db type argument
if($db_type !~ m/^inf$|^sql$|^mysql$|^ora$|^pro$|^syb$/)
{
  print "\nError: Invalid database type!\n";
  print "<db>: inf|sql|ora|pro|syb\n";
  print "\n";
  exit 0;
}

@dbmon_ng_to_ch = @dbmon_nodegroups_inf if ($db_type =~ m/^inf$/);
@dbmon_ng_to_ch = @dbmon_nodegroups_sql if ($db_type =~ m/^sql$/);
@dbmon_ng_to_ch = @dbmon_nodegroups_mysql if ($db_type =~ m/^mysql$/);
@dbmon_ng_to_ch = @dbmon_nodegroups_ora if ($db_type =~ m/^ora$/);
@dbmon_ng_to_ch = @dbmon_nodegroups_pro if ($db_type =~ m/^pro$/);
@dbmon_ng_to_ch = @dbmon_nodegroups_syb if ($db_type =~ m/^inf$/);

#Start script if all script validations passed
print "\nStaring assign_node.pl...\n";
system("touch $assign_dbmon_log");
print "Script logfile: $assign_dbmon_log\n";

#Check if dbmon nodegroups exists (passed by --db_type argument)
print "\nValidating DBMON nodegroups exists...";
foreach my $ng_to_val (@dbmon_ng_to_ch)
{
  my $r_validate_nodegroup_exists = validate_nodegroup_exists($ng_to_val);
  if ($r_validate_nodegroup_exists eq "1")
  {
    print "\rValidating DBMON nodegroups exists...FAILED!";
    print "\nNodegroup $ng_to_val does not exists!\nExiting script!\n\n";
    exit 0;
  }
}
print "\rValidating DBMON nodegroups exists...DONE!";

print "\nReading managed node(s) into memory...";
#Loads managed node(s) into array for processing
if ($nodename)
{
  $node_or_list[0] = $nodename;
}
if ($nodelist)
{
  open(INPUT_NODE_LIST, "< $nodelist")
    or die "File not found!\n";
  while(<INPUT_NODE_LIST>)
  {
    $read_node = $_;
    chomp($read_node);
    push(@node_or_list, $read_node);
  }
}
print "\rReading managed node(s) into memory...DONE!\n";
#Performs assigment node->nodegroup routine for loaded managed node array
foreach my $read_nodename (@node_or_list)
{
  chomp($read_nodename);
  print "\nNodename: $read_nodename\n";
  print "Checking node in HPOM database...";
  my @r_check_node_in_HPOM = check_node_in_HPOM($read_nodename);
  #If node was found in HPOM
  if ($r_check_node_in_HPOM[0] eq "1")
  {
    chomp($nodename_mach_type = $r_check_node_in_HPOM[3]);
    print "\rChecking node in HPOM database...DONE!";
    print "\nAssigning nodegroups to node...";
    my @r_assign_dbmon_nodegroups_to_node = assign_dbmon_nodegroups_to_node(\@dbmon_ng_to_ch, $read_nodename, $nodename_mach_type);
    my $failed_ng_out = "";
    #If sub retuned failed ng to assign
    if (@r_assign_dbmon_nodegroups_to_node)
    {
      foreach my $my_err_ng (@r_assign_dbmon_nodegroups_to_node)
      {
        $failed_ng_out = $failed_ng_out . ' ' .$my_err_ng;
        chomp($datetime_stamp_log = `date "+%m%d%Y_%H%M%S"`);
        script_logger($datetime_stamp_log, $assign_dbmon_log, "assign_dbmon_nodegroups_to_node():$read_nodename>>$my_err_ng:ASSIGNMENT_NOT_POSSIBLE");
      }
      print "\rAssigning nodegroups to node...FAILED!";
      chomp($failed_ng_out);
      print "\nFailed: $failed_ng_out\n";
    }
    else
    {
      print "\rAssigning nodegroups to node...DONE!";
    }
  }
  #If node was not found in HPOM
  else
  {
    print "\rChecking node in HPOM database...FAILED!";
    chomp($datetime_stamp_log = `date "+%m%d%Y_%H%M%S"`);
    script_logger($datetime_stamp_log, $assign_dbmon_log, "check_node_in_HPOM():$read_nodename:NODE_NOT_FOUND");
    next;
  }

}
#print "All parameters and options are good!\n";
print "\n\nScript logfile: $assign_dbmon_log\n";
print "\n";


#All script subs
######################################################################
# Sub that checks if a managed node is within a HPOM and if found determine its ip_address, node_net_type, mach_type
#	@Parms:
#		$nodename : Nodename to check
#	Return:
#		@node_mach_type_ip_addr = (node_exists, node_ip_address, node_net_type, node_mach_type, comm_type)	:
#															[0|1],
#															[<ip_addr>],
#															[NETWORK_NO_NODE|NETWORK_IP|NETWORK_OTHER|NETWORK_UNKNOWN|PATTERN_IP_ADDR|PATTERN_IP_NAME|PATTERN_OTHER],
#															[MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN|MACH_BBC_OTHER],
#                             [COMM_UNSPEC_COMM|COMM_BBC]
#		$node_mach_type_ip_addr[0] = 0: If nodename is not found within HPOM
#   $node_mach_type_ip_addr[0] = 1: If nodename is found within HPOM
######################################################################
sub check_node_in_HPOM
{
  my $nodename = shift;
	my $nodename_exists = 0;
	my @node_mach_type_ip_addr = ();
	my ($node_ip_address, $node_mach_type, $node_net_type, $node_comm_type) = ("", "", "", "");
	my @opcnode_out = qx{opcnode -list_nodes node_list=$nodename};
	foreach my $opnode_line_out (@opcnode_out)
	{
		chomp($opnode_line_out);
		if ($opnode_line_out =~ /^Name/)
		{
			$nodename_exists = 1;					# change to 0 if node is found
      push (@node_mach_type_ip_addr, $nodename_exists);
		}
		if ($opnode_line_out =~ m/IP-Address/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_ip_address = $1;
			chomp($node_ip_address);
			push (@node_mach_type_ip_addr, $node_ip_address);
		}
		if ($opnode_line_out =~ m/Network\s+Type/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_net_type = $1;
			chomp($node_net_type);
			push (@node_mach_type_ip_addr, $node_net_type);
		}
		if ($opnode_line_out =~ m/MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN|MACH_BBC_OTHER/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_mach_type = $1;
			chomp($node_mach_type);
			push (@node_mach_type_ip_addr, $node_mach_type);
		}
    if ($opnode_line_out =~ m/Comm\s+Type/)
    {
      $opnode_line_out =~ m/.*=\s(.*)/;
			$node_comm_type = $1;
			chomp($node_comm_type);
			push (@node_mach_type_ip_addr, $node_comm_type);
    }
	}
	# Nodename not found
	if ($nodename_exists eq 0)
	{
		$node_mach_type_ip_addr[0] = 0;
	}
  return @node_mach_type_ip_addr;
}

sub script_logger
{
  my ($date_and_time, $logfilename_with_path, $entry_to_log) = @_;
  open (MYFILE, ">> $logfilename_with_path")
   or die("File not found: $logfilename_with_path");
  print MYFILE "$date_and_time\:\:$entry_to_log\n";
  close (MYFILE);
}

sub csv_logger
{
  my ($logfilename_with_path, $entry_to_log) = @_;
  open (MYFILE, ">> $logfilename_with_path")
   or die("File not found: $logfilename_with_path");
  print MYFILE "$entry_to_log\n";
  close (MYFILE);
}

#Sub to validate that the dbmon nodegroups exist in HPOM
sub validate_nodegroup_exists
{
  my ($nodegroup) = @_;
  my @check_nodegroup = qx{opcnode -list_groups | grep ^Name | awk -F= '{print \$2}' | sed 's/^ //' | grep -e "^$nodegroup\$" > /dev/null};
  if ($? eq "0")
  {
    return 0
  }
  return 1;
}

######################################################################
# Sub to assign nodegroups to node
#	@Parms:
#		$node_group_arr_ref : array ref with db nodegroups
#   $node_name          : managed node
#   $node_mach_type     : managed node machine type
#	Return:
#   @err_ng_assign      : node groups which assignment was not possible
######################################################################
sub assign_dbmon_nodegroups_to_node
{
  my ($node_group_arr_ref, $node_name, $node_mach_type) = @_;
  my @node_group_arr_deref = @{$node_group_arr_ref};
  my @err_ng_assign;
  foreach my $c_dbmon_ng (@node_group_arr_deref)
  {
    chomp($c_dbmon_ng);
    #If node is Unix like
    if ($node_mach_type =~ m/MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX/)
    {
      #If db is Informix
      if ($c_dbmon_ng =~ m/_INFORMIX_/)
      {
        system("opcnode -assign_node node_name=$node_name group_name=$c_dbmon_ng net_type=NETWORK_IP > /dev/null");
        push(@err_ng_assign, $c_dbmon_ng) if($? ne "0");
      }
      #If not Informix assign nodegroups with _UX_ within nodegroup name
      else
      {
        if ($c_dbmon_ng =~ m/_UX_/)
        {
          system("opcnode -assign_node node_name=$node_name group_name=$c_dbmon_ng net_type=NETWORK_IP > /dev/null");
          push(@err_ng_assign, $c_dbmon_ng) if($? ne "0");
        }
      }
    }
    #If node is Windows
    if ($node_mach_type =~ m/MACH_BBC_WIN/)
    {
      #If db is MSSQL
      if ($c_dbmon_ng =~ m/_MSSQL_/)
      {
        system("opcnode -assign_node node_name=$node_name group_name=$c_dbmon_ng net_type=NETWORK_IP > /dev/null");
        push(@err_ng_assign, $c_dbmon_ng) if($? ne "0");
      }
      #If not MSSQL assign nodegroups with _WIN_ within nodegroup name
      else
      {
        if ($c_dbmon_ng =~ m/_WIN_/)
        {
          system("opcnode -assign_node node_name=$node_name group_name=$c_dbmon_ng net_type=NETWORK_IP > /dev/null");
          push(@err_ng_assign, $c_dbmon_ng) if($? ne "0");
        }
      }
    }
  }
  return @err_ng_assign;
}
