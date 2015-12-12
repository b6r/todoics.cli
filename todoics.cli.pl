#!/usr/bin/perl 
# ##############################################################################
# todoics.cli.pl
# -------------
# This is a tool for all the command line lovers wanting to work with todos
# using iCalender files. It is heavily inspired by Gina Trapani's Todo.txt-cli.
# If you use this in conjunction with vdirsyncer you can synchronize the 
# generated .ics files with the caldav server of your
# choice.
#
#
# Author: 	Jochen Becherer/b6r
# Version:	0.1.0
#
# todo: 
#	- debug messages
#	- view filter 
#	- all iCal properties
#
# (c) copyright 2015 Jochen Becherer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Dieses Programm ist Freie Software: Sie können es unter den Bedingungen
# der GNU General Public License, wie von der Free Software Foundation,
# Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
# veröffentlichten Version, weiterverbreiten und/oder modifizieren.
#
# Dieses Programm wird in der Hoffnung, dass es nützlich sein wird, aber
# OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
# Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
# Siehe die GNU General Public License für weitere Details.
#
# Sie sollten eine Kopie der GNU General Public License zusammen mit diesem
# Programm erhalten haben. Wenn nicht, siehe <http://www.gnu.org/licenses/>.
#
# SDG
# ##############################################################################
use strict;
use Getopt::Long;
use Pod::Usage;
use Time::Local;
use Term::ANSIColor;
use utf8;

# ##############################################################################
# ##                                                                          ##
# ##                                   Main                                   ##
# ##                                                                          ##
# ##############################################################################
$ENV{'LANG'} = 'de_DE.UTF-8';
$ENV{'LC_CTYPE'} = 'de_DE.UTF-8';


# ########################### #
# Read command line arguments #
# ########################### #
my $showAll	= 0;
my $show 	= 0;
my $new 	= 0;
my $close 	= 0;
my $modify	= 0; 
my $help	= 0;
my $debug	= '';
my $erase	= 0;
my $force	= 0;
GetOptions(
	'showall|a'	=> \$showAll,
	'show|s' 	=> \$show,
	'new|n' 	=> \$new,
	'close|c'	=> \$close,
	'modify|m'	=> \$modify,
	'help|h'	=> \$help,
	'debug|d=s'	=> \$debug,
	'erase|e'	=> \$erase,
	'force|f'	=> \$force
);


# ################# #
# Initialize script #
# ################# #
# Define debug level 
my %debugLevel = (
	ERROR 	=> 0,
	WARN	=> 1,
	INFO	=> 2, 
	DEBUG	=> 3
);

# Standard configuration
my %config = (
	icsFiles 	=> "$ENV{'HOME'}/.config/vdirsyncer/cals/jochen",
	cacheFile	=> "$ENV{'HOME'}/.local/todoics.cli/cache.db",
	debug		=> $debugLevel{'ERROR'},
	autocleanup => 1,
	daystoerase	=> 7
);

%config = %{&readConfigFile()};

# Take user changes to standard config into account
if ($debug ne '') {
	$config{'debug'} = $debugLevel{$debug};
}


# Initialize todo cache
my %cache;
my %rcache;
my $maxNum = 0;
&fillCache();


# ####################### #
# Start script processing #
# ####################### #

if ($help) {
	pod2usage(1);
} elsif ($showAll) {
	# Show all ToDos
	&showToDos(0);
} elsif ($show) {
	# Show all currently open ToDos
	&showToDos(1);
} elsif ($new) {
	# Create new ToDos
	&createNewTodo(\@ARGV);
} elsif ($close) {
	# Set a ToDo in status COMPLETE
	&closeToDo(\@ARGV);
} elsif ($modify) {
	# Modify a ToDo
	&modifyToDo(\@ARGV);
} elsif ($erase) {
	# Erase old completed ToDos
	if (! $force) {
		&getToDosFromFiles(2);
	} else {
		&getToDosFromFiles(3);
	}	
} else {
	# Show help message	
	print "No parameters - don't know what to do. Try todoics.cli.pl --help.\n";
}


# ############### #
# Finalize script #
# ############### #
&saveCache();


# ##############################################################################
# ##                                                                          ##
# ##                                   subs                                   ##
# ##                                                                          ##
# ##############################################################################


# ##############################################################################
# showToDos
# ---------
# Displays all open tasks taken from the .ics files from filesytem
#
# params: nothing
# return: nothing
# ##############################################################################
sub showToDos {
	my $mode = shift;
	my %toDos = %{&getToDosFromFiles($mode)};

	print "Your todos:\n";

	my $maxNumber = length('Nr.');
	my %cacheUsed;
	foreach my $numUsed (keys %cache) {
		if (exists $toDos{$cache{$numUsed}}) {
			$cacheUsed{$numUsed} = $cache{$numUsed};
			my $lengthNum = length("$numUsed");
			$maxNumber = ($lengthNum > $maxNumber) ? $lengthNum : $maxNumber;
		}
	}

	my @keys = sort { $a <=> $b } keys %cacheUsed;
	foreach my $num (@keys) {
		my %todo = %{$toDos{$cacheUsed{$num}}};
 		my $hrDate = &getHRDateString($todo{'DUE'});
		my $dueEpoch = int &dateTimeStringtoEpoch($todo{'DUE'});
		my $inTime = $dueEpoch - (time-(60*60*24));

		my $summary = $todo{'SUMMARY'};
		if ($todo{'STATUS'} eq 'COMPLETED') {
			print color('blue');
		} else {	
			if ($inTime < 0) { 
				print color('red');
			} else {
				print color('green');
			}
		}	
		printf "%0${maxNumber}s: %s prio=%s", $num, $summary, $todo{'PRIORITY'};
		print " due=$hrDate" if ($hrDate ne '');
		print " cat=$todo{'CATEGORIES'}" if ($todo{'CATEGORIES'} ne '');
		print "\n";
		print color('reset');
	}	
	print "\n";
}	


# ##############################################################################
# createToDo
# ----------------
# Creates a new todo-Entry.$todo{'PRIORITY'}
#
# params: Reference to @ARGV array
# return: nothing
# ##############################################################################
sub createNewTodo {
	my $args = shift;

	my $summary 	= '';
	my $duedate 	= '';
	my @categories	= ();
	my $prio		= '';
	my $class		= 'PRIVATE';
	foreach my $item (@{$args}) {
		if ($item =~ /due/) {
			(my $label, $duedate) = split /=/, $item;	
			$duedate = &analyzeDueDate($duedate, time);
		} elsif ($item =~ /prio/) {
			(my $label, $prio) = split /=/, $item;
		} elsif ($item =~ /\*(.*)/) {
			push @categories, $1;
		} elsif ($item =~ /@(.*)/) {
			$class = ($1 == 'PUBLIC' || $1 == 'CONFIDENTIAL') ? $1 : $class;
		} else {
			$summary = $summary . $item . ' ';
		}	
	}	

	my $dateString = &getFormattedDateString(time);
	my $uid = unpack('H*', ${dateString} .substr($summary, 0, 8)) . "_todocli";
	my %thisToDo = (
		'UID' 			=> "$uid",
		'CREATED' 		=> "${dateString}",
		'LAST-MODIFIED'	=> "${dateString}",
		'DTSTAMP'		=> "${dateString}",
		'SUMMARY'		=> &trim(${summary}),
		'STATUS' 		=> "NEEDS-ACTION",
		'CLASS'			=> "$class"
	);
			
	if ($#categories+1 > 0) {	
		$thisToDo{'CATEGORIES'} = join(',', @categories);
	}

	if ($duedate ne '') {
		$thisToDo{'DUE'} = "${duedate}";
	}

	if ($prio ne '') { 
		$thisToDo{'PRIORITY'} = "${prio}";
	}	

	if ($summary ne '') {
		print "DEBUG: Write todo to $config{'icsFiles'}/${uid}.ics\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
		open THISICS, '>', "$config{'icsFiles'}/${uid}.ics" || die "Cannotopenfile\n";
		print THISICS &makeToDoStringFromHash(\%thisToDo);
		close THISICS;

		$cache{++$maxNum} = $uid;
		$rcache{$uid} = $maxNum;
	} else {
		print "ERROR" if ($config{'debug'} >= $debugLevel{'ERROR'});
	}	
}


# ##############################################################################
# completeToDo
# ------------
# Closes a task by setting STATUS to COMPLETED and COMPLETED/LAST-MODIFIED to 
# the current timestamp.
#
# params: The @ARGV array as a reference
# return: nothing
# ##############################################################################
sub closeToDo {
	my $args = shift;
	print "${$args}[0]\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
	
	my $fileContent = '';
	open ICALFILE, '<', "$config{'icsFiles'}/$cache{${$args}[0]}.ics";
	while (<ICALFILE>) {
		chomp;
		$fileContent =  $fileContent . $_ . "\n";
	}
	close ICALFILE;

	my $thisToDo = &makeToDoHashFromString($fileContent);		
	my $thisTime = &getFormattedDateString(time);
	print "Closing ToDo ${$thisToDo}{'SUMMARY'}\n";

	${$thisToDo}{'STATUS'} = "COMPLETED";
	${$thisToDo}{'COMPLETED'} = $thisTime;
	${$thisToDo}{'LAST-MODIFIED'} = $thisTime;

	open ICALFILE, '>', "$config{'icsFiles'}/$cache{${$args}[0]}.ics";
	print ICALFILE &makeToDoStringFromHash($thisToDo); 	
	close ICALFILE;
}


# ##############################################################################
# modifyToDo
# ----------
# Changes the properties of a todo to the values provided via command line
# arguments. The new generated .ics will be stored in the destination directory.
#
# params: @ARGV
# return: nothing
# ##############################################################################
sub modifyToDo {
	my $args = shift;

	my $id = ${$args}[0];
	if ($id !~ /\d+/ || ! exists $cache{$id}) {
		print "First argument must be a valid id\n";
	}	

	my $fileContent = '';
	open ICALFILE, '<', "$config{'icsFiles'}/$cache{$id}.ics";
	while (<ICALFILE>) {
		chomp;
		$fileContent =  $fileContent . $_ . "\n";
	}
	close ICALFILE;

	my $thisToDo = &makeToDoHashFromString($fileContent);	
	foreach my $arg (@{$args}) {
		if ($arg =~ /prio=(.*)/) {
			${$thisToDo}{'PRIORITY'} = $1;
		} elsif ($arg =~ /due=(.*)/) {
			my $oldTimeStamp = &dateTimeStringtoEpoch(${$thisToDo}{'DUE'});
			$oldTimeStamp = ($oldTimeStamp == 0) ? time : $oldTimeStamp;
			${$thisToDo}{'DUE'} = &analyzeDueDate($1, $oldTimeStamp);
		} elsif ($arg =~ /\*([\+-]{1})(.*)/) {
			if ($1 eq '+') {
				${$thisToDo}{'CATEGORIES'} = (${$thisToDo}{'CATEGORIES'} eq '') ? $2 : ${$thisToDo}{'CATEGORIES'} . ",$2";
			} elsif ($1 eq '-') {	
				my @categories = split /,/, ${$thisToDo}{'CATEGORIES'};
				my $newCategories = '';
				foreach my $categorie (@categories) {
					if ($categorie ne $2) {
						$newCategories = ($newCategories eq '') ? $categorie : $ $newCategories . ",${categorie}";
					}
				}
				${$thisToDo}{'CATEGORIES'} = $newCategories;
			}	
		} elsif ($arg =~ /\*(.*)/) {
			${$thisToDo}{'CATEGORIES'} = $1;
		}	
	}

	${$thisToDo}{'LAST-MODIFIED'} = &getFormattedDateString(time);

	open ICALFILE, '>', "$config{'icsFiles'}/$cache{$id}.ics";
	print ICALFILE &makeToDoStringFromHash($thisToDo); 	
	close ICALFILE;
}	


# ##############################################################################
# readConfigFile
# --------------
# Read the config file and use its config 
#
# params: Alternative location for the config file
# return: config hash
# ##############################################################################
sub readConfigFile {
	my $configFile = shift;
	$configFile = ($configFile eq '') ? "$ENV{'HOME'}/.config/todoics.cli/todoics.cli.conf" : $configFile;

	my %localConfig;

	print "DEBUG: Reading config file ${configFile}.\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
	open CONFIG, "<$configFile" || die "Cannot open config file. Terminating!";
	while (<CONFIG>) {
		chomp;
		if (! /^#/ && ! /^$/) {
			my ($label, $value) = split /=/;
			$label = &trim($label);
			$value = &trim($value);
			if ($value =~ /~/) {
				$value =~ s/~/$ENV{'HOME'}/;
			}

			$localConfig{$label} = $value;
		}
	}
	close CONFIG;

	return \%localConfig;
}


# ##############################################################################
# fillCache
# ---------
# Reads the local cache file and saves it to the cache Hash. Provides a better
# human readable identifier for a todo.
# 
# params: nothing
# return: nothing
# ##############################################################################
sub fillCache {
	print "DEBUG: Reading cache file $config{'cacheFile'}.\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
	open CACHE, "<$config{'cacheFile'}";
	while(<CACHE>) {
		chomp;
		my ($num, $uid) = split /:/;
		$cache{$num} = $uid;
		$rcache{$uid} = $num;
		$maxNum = ($num > $maxNum) ? $num : $maxNum;
		print "DEBUG: ${num}$:${uid} ($maxNum)\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
	}
	close CACHE;
}


# ##############################################################################
# saveCache
# ---------
# Saves the internal cache to local file.
# 
# params: nothing
# return: nothing
# ##############################################################################
sub saveCache {
	open CACHE, ">$config{'cacheFile'}";
	foreach my $key (keys %cache) {
		if ($key ne '' && $cache{$key} ne '') {
			print "DEBUG: ${key}:${cache{$key}}\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
			print CACHE "${key}:$cache{$key}\n";
		}
	}
	close CACHE;
}


# ##############################################################################
# getToDosFromFiles
# -----------------
# Read all .ics files from filesystem and store .ics containing tasks in a
# Hash.
#
# params: nothing
# return: Hash (key=UID) of Hashes with all tasks
# ##############################################################################
sub getToDosFromFiles {
	my $mode = shift;
	my %toDos;

	opendir(ICALS, $config{'icsFiles'}) or die "Cannot open dir $config{'icsFiles'}";
	while (defined (my $iCalFile = readdir(ICALS))) {
		if ($iCalFile =~ /\S+\.ics/) {
			open ICALFILE, '<', "$config{'icsFiles'}/${iCalFile}";

			my $isTodo = 0;
			my $fileContent = '';
			while (<ICALFILE>) {
				chomp;
				$fileContent =  $fileContent . &trim($_) . "\n";
				if (/VTODO/) {
					$isTodo = 1;
				}
			}

			if ($isTodo) {
				my $thisToDo = &makeToDoHashFromString($fileContent);		

				my $status 	= ${$thisToDo}{'STATUS'};
				my $uid		= ${$thisToDo}{'UID'};
				if ($mode == 0 || ($mode == 1 && $status ne 'CANCELED' && $status ne 'COMPLETED')) {
					print "TODO $uid is of status $status. Going to show it.\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
					$toDos{$uid} = $thisToDo;

					if (! exists $rcache{$uid}) {
						$cache{++$maxNum} = $uid;
						$rcache{$uid} = $maxNum;
					}
				} elsif (($mode >= 2 || $config{'autocleanup'} == 1) && ($status eq 'CANCELED' || $status eq 'COMPLETED')) {
					if ($mode == 3 || &dateTimeStringtoEpoch(${$thisToDo}{'COMPLETED'}) < (time - $config{'daystoerase'}*24*60*60)) {
						print "Deleting ${iCalFile}\n";
						my $id = $rcache{$uid};
						delete $cache{$id};
						delete $rcache{$uid};
						unlink "$config{'icsFiles'}/${iCalFile}";
					} 
				} else {
					print "DEBUG: TODO $uid is of status $status, but only open TODOs are requested\n" if ($config{'debug'} >= $debugLevel{'DEBUG'});
				}
			}	
		} 
	}
	closedir ICALS;

	return \%toDos;
}


# ##############################################################################
# makeToDoHashFromString
# ----------------------
# Take a newline delimited string from .ics file and create a hash with iCal
# properties as keys.
#
# params: newline delimited string
# return: reference of created hash
# ##############################################################################
sub makeToDoHashFromString {
	my $fileContent = shift;
	my %thisToDo;

	my @properties = split /\n/, $fileContent;
	foreach my $property (@properties) {
		my ($key, $value) = split /:/, $property;
		$thisToDo{$key} = $value;
		print "DEBUG: $key = $value\n" if ($config{debug} >= $debugLevel{'DEBUG'});
	}

	return \%thisToDo;
}	


# ##############################################################################
# makeToDoStringFromHash
# ----------------------
# Takes a hash with todo properties and transfers this into a string to be
# stored in a .ics file.
#
# params: Hash with todo properties
# return: String to be stored in .ics file
# ##############################################################################
sub makeToDoStringFromHash {
	my $thisToDo = shift;

	my $icsString 	 = "BEGIN:VCALENDAR\n";
	$icsString		.= "VERSION:2.0\n";
	$icsString		.= "PRODID:de.b6r.todocli_v0.0.1\n"; 
	$icsString		.= "BEGIN:VTODO\n";
	$icsString		.= "UID:${$thisToDo}{'UID'}\n"; 
	$icsString		.= "CREATED:${$thisToDo}{'CREATED'}\n"; 
	$icsString		.= "LAST-MODIFIED:${$thisToDo}{'LAST-MODIFIED'}\n";
	$icsString		.= "DTSTAMP:${$thisToDo}{'DTSTAMP'}\n"; 
	$icsString		.= "SUMMARY:${$thisToDo}{'SUMMARY'}\n"; 
	$icsString		.= "STATUS:${$thisToDo}{'STATUS'}\n"; #or ,"IN-PROCESS","CANCELLED}"

	$icsString = (${$thisToDo}{'CLASS'} ne '') ? $icsString . "CLASS:${$thisToDo}{'CLASS'}\n" : $icsString . "CLASS:PRIVATE\n";
	$icsString = (${$thisToDo}{'CATEGORIES'} ne '') ? $icsString . "CATEGORIES:${$thisToDo}{'CATEGORIES'}\n" : $icsString;
	$icsString = (${$thisToDo}{'DUE'} ne '') ?	$icsString . "DUE:${$thisToDo}{'DUE'}\n" : $icsString;
	$icsString = (${$thisToDo}{'PRIORITY'} ne '') ? $icsString . "PRIORITY:${$thisToDo}{'PRIORITY'}\n" : $icsString . "PRIORITY:0\n";
	$icsString = (${$thisToDo}{'COMPLETED'} ne '') ? $icsString . "COMPLETED:${$thisToDo}{'COMPLETED'}\n" : $icsString;

	$icsString .= "END:VTODO\n";
	$icsString .= "END:VCALENDAR\n";
		
	return $icsString;
}


# ##############################################################################
# analyzeDueDate
# --------------
# Analyzes the given duedate String and creates a date String in the format
# yyyymmddThhmmssZ.
# "Understands" the following formats:
# - dd.mm.yyyy (German format)
# - yyyymmdd
# - yyyymmddhhmm
# - yyyymmddhhmmss
# - +/-n[Yy] = n years in the future/past
# - +/-n[Mm] = n months in the future/past
# - +/-n[Dd] = n days in the future/past
# - +/-n[Ww] = n weeks in the futzre/past
#
# params: duedate String
# return: yyyymmddThhmmssZ
# ##############################################################################
sub analyzeDueDate {
	my $duedate = shift;
	my $time	= shift;

	if ($duedate =~ /^(\d\d)\.(\d\d)\.(\d\d\d\d)$/) {
		$duedate = &getFormattedDateString(timegm(0, 0, 0, $1, ($2-1), $3));	
	} elsif ($duedate =~ /^(\d{4})(\d{2})(\d{2})$/) {
		$duedate = &getFormattedDateString(timegm(0, 0, 0, $3, ($2-1), $1));
	} elsif ($duedate =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
		$duedate = &getFormattedDateString(timegm(0, $5, $4, $3, ($2-1), $1));
	} elsif ($duedate =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
		$duedate = &getFormattedDateString(timegm($6, $5, $4, $3, ($2-1), $1));
	} elsif ($duedate =~ /^([\+-]+)(\d+)([YyMmDdWw])$/) {
			$duedate = &changeDate($time, $3, $1,  $2);
	} else {
		$duedate = "ERROR";
	}

	return $duedate;
}


# ##############################################################################
# getFormattedDateString
# ----------------------
# Takes an epoch String and converts it into a human readable String in the
# format yyyymmddThhmmssZ
#
# params: Epoch String
# return: yyyymmddThhmmssZ
# ##############################################################################
sub getFormattedDateString {
	my $time = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);	
	return sprintf '%04d%02d%02dT%02d%02d%02dZ', ${year}+1900, ${mon}+1, ${mday}, ${hour}, ${min}, ${sec};

}


# ##############################################################################
# dateTimeStringtoEpoch
# ---------------------
# Converts a Date-Time String from .ics file into an UTC epoch String.
#
# params: Date-Time String
# return: Epoch String
# ##############################################################################
sub dateTimeStringtoEpoch {
	my $dateTimeString = shift;
	if ($dateTimeString =~ /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/) {
		my $epoch = timegm($6, $5, $4, $3, ($2-1), ($1-1900));
		return $epoch;
	}

	return 0;
}


# ##############################################################################
# getHRDateString
# Converts a Date-Time String into a human readable String. Ok, it's a german
# format. Internationalization and configuration needs to be done in future 
# versions (if ever needed).
#
# params: Date-Time String
# return: String in format dd.mm.yyyy hh.mm
# ##############################################################################
sub getHRDateString {
	my $epochUtc = &dateTimeStringtoEpoch($_[0]);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($epochUtc);

	return sprintf "%02d.%02d.%04d %02d:%02d", $mday, ($mon+1), ($year+1900), $hour, $min;
}


# ##############################################################################
# changeDate
# ----------
# Changes a given date in epoch String in a defined way.
# It is possible to increase or decrease the value by year, month, day or week.
#
# params: epoch String as starting point
#		  interval of change (possible values are [Yy], [Mm], [Dd], [Ww]
#		  direction of change (possible values are + and -
#         number of steps
# return: Formatted String yyyymmddThhmmssZ
# ##############################################################################
sub changeDate {
	my $now 		= shift;
	my $what		= shift;
	my $direction 	= shift;
	my $number		= shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);	

	if ($what =~ /[Yy]/) {
		$now = ($direction eq '+') ? $now + ($number*365*24*60*60) : $now - ($number*365*24*60*60);
	} elsif ($what =~ /[Mm]/) {
		$now = ($direction eq '+') ? $now + ($number*30*24*60*60) : $now - ($number*30*24*60*60);
	} elsif ($what =~ /[Dd]/) {
		$now = ($direction eq '+') ? $now + ($number*24*60*60) : $now - ($number*24*60*60);
	} elsif ($what =~ /[Ww]/) {
		$now = ($direction eq '+') ? $now + ($number*7*24*60*60) : $now - ($number*7*24*60*60);
	}

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);
	return &getFormattedDateString(timegm($sec, $min, $hour, $mday, $mon, $year));
}


# ##############################################################################
# trim
# ----
# Remove blanks at beginning and end of a string.
#
# params: String
# return: String with blanks removed.
# ##############################################################################
sub trim {
	my $text = shift;
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return $text;
}

__END__

=head1 NAME

todoics.cli.pl - Tool to work with iCalener TODOs.

=head1 SYNOPSIS

todoics.cli.pl [options] task description

=head1 OPTIONS

=over

=item 
--showall or -a
Shows all todos in the iCalendar directory.

=item 
--show or -s
Shows all open todos in the iCalendar directory.

=item
--new or -n
Creates a new todo entry.

=item
--close or -c
Closes the task identfied by todo number. 

=item
--modify or -m
Modifies the task identified by todo number.

=item
--help or -h
Shows this help.

=item
--debug or -d
Sets the debug level.

=item
--erase or -e
Deletes all completed todos.

=back

=cut
