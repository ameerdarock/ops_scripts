#!/usr/bin/perl 
use strict;
use warnings;
use File::Tail;
use File::Pid;
use POSIX qw(setsid);
use Sys::Syslog qw( :DEFAULT setlogsock);

### parse gpfs io waiters file and alert
# Check the gpfs waiters logfile for waiters exceeding $wait_delay and write to syslog and send email alerts
# Send only $max_mails, then wait $mail_delay before sending mail again, to prevent excessive mails, as multiple threads
# usually slow down by the block on the cluster
# 6/15/2012
# Started ignoring any waiters with the command tsdeldisk in it; this is to avoid alerts when we are doing disk movements.
# A tsdeldisk waiter will be active for the entire time the disk is being evacuated.
# 12/2012
# The production file was deleted, editing the staging one which was missing some changes; tuning it up and putting into RCS on sanman
# 07/24/2013
# gpfs version 3.4 changes the tsdeldisk warning; adjusted the regex to ignore
# deldisk activities
# 08/05/2013

###CONFIG
my $app = 'Production-DAS';
my $app_alert = "\"GPFS waiter warning for: $app\"";
my $logfile = '/tmp/mmfs/monitor.waiters.log';
my $wait_delay = 180; #seconds
my $file;
my $line;
# MAIL
my $mail_sent;
my $mail_delay = 600; #seconds.  Time to wait before sending mails again
my $max_mails = 5;
my $mail_count = 0;
#my $warn_dist = 'ameer.dixit@gettyimages.com';
my $warn_dist = 'TSNOCAlert@gettyimages.com,TSStorage@gettyimages.com';
# PID
my $pid_file = '/var/run/gpfs_monitor.pid';
my $die_now = 0;

### END OF CONFIG

sub WriteToSyslog {
    my $message = shift(@_); 
    setlogsock('unix');
    openlog('gpfs_alert','','user');
    syslog('crit', $message);
    closelog;
}

sub SendMail {
	my $mailbody = shift(@_);
	my $now = time;
	# are we in window to not send mail?
	if ( $mail_count >= $max_mails ) {
		if ( ( $now - $mail_delay ) > $mail_sent ) {
			# enough time has passed
			#$mail_sent = 0;
			undef $mail_sent;
			$mail_count = 0;
			WriteToSyslog("Reseting mail threshold after $mail_delay seconds\n");
		}
		else {
			WriteToSyslog("At mail max, supressing warning. \n");
			# debug:  $now minus $mail_delay less than $mail_sent
			return;
		}
	}
	open MAIL, "| /bin/mailx -s $app_alert  $warn_dist";
	print MAIL $mailbody;
	close MAIL;
	$mail_count++;
	if ( ! defined($mail_sent)) {
		$mail_sent = time;
		WriteToSyslog("Setting mail first sent time at $now\n");
	}			
}
sub signalHandler {
$die_now = 1;    # this will cause the "infinite loop" to exit
}

#START
# daemonize
chdir '/';
umask 0;
open STDIN,  '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!";
defined( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;
POSIX::setsid() or die "Can't start a new session.";
# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';
# already running?
my $pidfile = File::Pid->new({file => $pid_file});
if ( my $num = $pidfile->running ) {
	WriteToSyslog("Can't start GPFS waiter monitor.  Already running as $num\n");
	SendMail("Can't start GPFS waiter monitor.  Already running as $num\n");
	die; 
}
# log pid file
$pidfile->write;
$pidfile->write or die "Can't write PID file, /dev/null: $!";
WriteToSyslog("Starting gpfs monitor for $app...");
# make sure both tail and reset_tail are set to 0
# otherwise, when gpfs occasionally makes a change to the file, it processes the entire file over
$file=File::Tail->new(name=>$logfile, maxinterval=>3, adjustafter=>7, tail=>0, reset_tail=>0);
while (defined($line=$file->read)) {
      if ( $line =~ m/^(\w+)-(\w+)\.production.local\:(\s+)(\w+)(\s+)waiting(\s+)(\d+)\.(\d+)(\s+)seconds,(\s+)(\w+)/ ) {
	# $11 should be the word after the comma
	if ( $7 > $wait_delay && $11 ne 'TSDELDISKCmdThread' ) {
		# hit the warning threshold
		my $warn_message = "Contact Storage Oncall Immediately; GPFS cluster waiter detected. \n \n Long waiter for cluster $app: $1 thread $4 waiting $7 seconds; function: $11";
		WriteToSyslog($warn_message);
		SendMail($warn_message);
		}
	}
	#check if its time to stop
	if ( $die_now != 0) {
		WriteToSyslog("Stopping gpfs monitor for $app...");
		$pidfile->remove if defined $pidfile;		
		$pidfile->remove;
		die;
	}
}
