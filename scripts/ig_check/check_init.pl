#!/usr/bin/perl -w
# /opt/emc/SYMCLI/bin/symaccess -sid 0994 list -type initiator

use Data::Dumper;
#Globals
my $ins_path = "/opt/scripts/ig_check/";
my $ignored_igs = "${ins_path}ignore.txt";
my $init_list = "${ins_path}all_inits.out";
#my $output="good.out";
my @full_IG;
my @listed_IG;
my @ignore_IG;

# slurp the IG's to ignore 
open (ignoreFH, "< $ignored_igs") || error_handler("Unable to open ignore list for reading: $ignored_igs"); 
while (<ignoreFH>) {
	push(@ignore_IG,$_);
}
close ignoreFH || error_handler("Could not close ignore list:  $ignored_igs");
	
# generate list of IG's on the array
@full_IG = `/opt/emc/SYMCLI/bin/symaccess -sid 0994 list -type initiator`;
foreach ( @full_IG ) {
	if ( $_ =~ /_IG/ ) {
		push(@listed_IG, $_);
	}
}
# make sure this array has some IGs in it
unless ( scalar @listed_IG > 5 ) {
	error_handler("IG list is too small.  Check symaccess output.\n");
}
# get a hash of wwids for each IG

die; 
# check each initiator is logged in

open (my $FH1, "> $output");
open (my $FH, "< $file");
while ( <$FH> ) {
my $IG = $_;
chomp ($IG);
my @inits = `symaccess -sid 0994 show $IG -type initiator | grep WWN | cut -c 15-31`;
foreach (@inits) {
my $init = $_;
chomp ($init);
my $logins = ` symaccess -sid 0994 list logins -wwn $init | grep $init`;
#print $logins;
if ( $logins =~ /^\w+\s\w+\s\w+\s+\w+\s+\w+\s(\w+)*/ ) {
	my $state = $1;
	if ( $state ne "Yes" ) {
		print "$IG has initiator $init in state $state\n";
		}
	else {
		print $FH1 "$IG $init $state\n";
		}
	}
	}
}
close($FH1);
close($FH);

# SUBS

sub error_handler {
        my $error_msg = shift;
        open(MAIL, '| /usr/sbin/sendmail -t -oi') ||die("Can't open pipe to sendmail, this is bad:\n $!\n");
        #print MAIL "To: TSStorage\@gettyimages.com \n";
        #print MAIL "To: ameer.dixit\@gettyimages.com \n";
        print MAIL "From: VMAX IG Check\n";
        print MAIL "Subject: Error checking initiator groups\n";
        print MAIL "Content-type: text/html\n\n";
        print MAIL "
                $error_msg
        ";
        close MAIL;
        exit;
}
