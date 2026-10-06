#!/usr/bin/perl -w

# fapg@eurotux.com

use strict;
use warnings;
use Data::Dumper;

use Monitoring::Plugin;

my $plugin = Monitoring::Plugin->new(
    plugin => "check_bird_proto", shortname => "BIRD_PROTO", version => "0.4",
    usage => "Usage: %s -p <peer> [-r] [-d]",
);
$plugin->add_arg(
    spec => "peer|p=s",
    help => "The name of the peer protocol session name to monitor.",
    required => 1,
);
$plugin->add_arg(
    spec => "routeserver|r",
    help => "Route server mode: don't warn on 0 imported routes.",
    default => 0,
);
$plugin->add_arg(
    spec => "debug|d",
    help => "Verbose for this script.",
    default => 0,
);
$plugin->getopts;

# Handle timeouts (also triggers on invalid command)
$SIG{ALRM} = sub { $plugin->nagios_exit(CRITICAL, "Timeout (possibly invalid command)") };
alarm $plugin->opts->timeout;

my $birdc = "/usr/sbin/birdc";
my $peer2check;
my $output ="";
my $status = "";
my $since = "";
my $info = "";

if ( $plugin->opts->peer =~ /(^[\w\-]+$)/) {
    $peer2check = $1;

    # check if birdc is accessible
    unless (-x $birdc) {
        $plugin->nagios_exit(CRITICAL, "birdc not found or not executable: $birdc");
    }

    print "DEBUG: $birdc show protocols all $peer2check\n" if $plugin->opts->debug;
    # see the details for the peer provider
    my @peer = qx/$birdc show protocols all $peer2check 2>&1/;
    my $exit_code = $? >> 8;
    print Dumper \@peer if $plugin->opts->debug;

    if ($exit_code != 0 || !@peer) {
        $plugin->nagios_exit(CRITICAL, "birdc failed (exit code $exit_code): cannot connect to BIRD");
    }

    if (defined($peer[2])) {
        print "DEBUG in the peer if : $peer[2]\n" if $plugin->opts->debug;
	# BIRD 2 example
	# NOS_ipv4   BGP        ---        up     2020-09-22    Established
	# PCH1_2001_7f8_a_1__55 BGP        ---        down   11:21:54.010
	#
	# BIRD 1 example
	# Node_X BGP      master   up     20:26:27    Established
        if ($peer[2] =~ m/^[\w\-]+\s+BGP\s+(?:---|master)\s+(\w+)\s+([\d\-\.\:]+)(.*)/) {
            $status = $1;
            $since = $2;
            my $tail = $3;
            $tail =~ s/^\s+//;
            if ($tail ne "") {
                $info = $tail;
            } else {
                $info = "down";
            }

            if ($status eq "up") {
                $output = "$peer2check $status since $since with connection $info";

                my $string = join( ',', @peer );
                print "STRING: $string\n" if $plugin->opts->debug;
                if ($string =~ m/Routes:\s+(\d+) imported,\s+(\d+) exported,\s+(\d+) preferred/) {
                    my ($imported, $exported, $preferred) = ($1, $2, $3);
                    # check if i've more than one route...
                    if ($imported >= 1) {
                        print "DEBUG in the routes if : ROUTES: $imported\n" if $plugin->opts->debug;
                        $output .= " routes: $imported exported:$exported preferred: $preferred|'established_routes'=$imported;;;0 'exported_routes'=$exported;;;0 'preferred_routes'=$preferred;;;0";
                        $plugin->nagios_exit(OK, "$output");
                    } elsif ($plugin->opts->routeserver) {
                        $output .= " routes: $imported exported:$exported preferred: $preferred|'established_routes'=$imported;;;0 'exported_routes'=$exported;;;0 'preferred_routes'=$preferred;;;0";
                        $plugin->nagios_exit(OK, "$output");
                    } else {
                        $plugin->nagios_exit(WARNING, "Too few routes for this provider: $imported");
                    }
                } else {
                    $plugin->nagios_exit(CRITICAL, "Could not parse routes for $peer2check");
                }
            } else {
                $plugin->nagios_exit(CRITICAL, "Peer down: status: $status + info: $info.");
            }
        } else {
            $plugin->nagios_exit(CRITICAL, "Peer protocol session name status doesn't match: $peer[2]");
        }
    } else {
        $plugin->nagios_exit(CRITICAL, "Peer protocol session name doesn't exist: $peer2check.");
    }
} else {
    $plugin->nagios_exit(CRITICAL, "Wrong character for peer provider.");
}
