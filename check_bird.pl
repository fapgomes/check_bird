#!/usr/bin/perl -w

# fapg@eurotux.com

use strict;
use warnings;
use Data::Dumper;

use Monitoring::Plugin;

my $plugin = Monitoring::Plugin->new(
    plugin => "check_bird_proto", shortname => "BIRD_PROTO", version => "0.3",
    usage => "Usage: %s -p <peer> [-rs]",
);
$plugin->add_arg(
    spec => "peer|p=s",
    help => "The name of the peer protocol session name to monitor.",
    required => 1,
);
$plugin->add_arg(
    spec => "routeserver|r",
    help => "The name of the peer protocol session name to monitor.",
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

if ( $plugin->opts->peer =~ /(^[\w\d\_\-]+$)/) {
    $peer2check = $1;
    print "DEBUG: $birdc show protocols all $peer2check\n" if $plugin->opts->debug;
    # see the details for the peer provider
    my @peer = qx/$birdc show protocols all $peer2check/;
    print Dumper \@peer if $plugin->opts->debug;
    # remove headers from command line
    #shift @peer for 1..2;
    if (defined($peer[2])) {
        print "DEBUG in the peer if : $peer[2]\n" if $plugin->opts->debug;
	# NOS_ipv4   BGP        ---        up     2020-09-22    Established
	# PCH1_2001_7f8_a_1__55 BGP        ---        down   11:21:54.010
        if ($peer[2] =~ m/^[\w\d\_\-]+\s+BGP\s+---\s+(\w+)\s+([\d+\-\.\:]+)(.*)/) {
            $status = $1;
            $since = $2;
            if ($3 ne "  ") {
                $info = $3;
            } else {
                $info = "down";
            }

            if ($status eq "up") {
                $output = "$peer2check $status since $2 with connection $info";

                my $string = join( ',', @peer );
                print "STRING: $string\n" if $plugin->opts->debug;
                $string =~ m/Routes:\s+(\d+) imported,\s+(\d+) exported,\s+(\d+) preferred/;
                # check if i've more than one route...
                if ($1 >= 1) {
                    print "DEBUG in the routes if : ROUTES: $1\n"if $plugin->opts->debug;
                    $output .= " routes: $1 exported:$2 preferred: $3|'established_routes'=$1;;;0 'exported_routes'=$2;;;0 'preferred_routes'=$3;;;0";
                    $plugin->nagios_exit(OK, "$output");
                } elsif ($plugin->opts->routeserver) {
                    $plugin->nagios_exit(OK, "$output");
                } else {
                    $plugin->nagios_exit(WARNING, "To few routes for this provider: $1");
                }
            } else {
                $plugin->nagios_exit(CRITICAL, "Peer down: status: $status + info: $info.");
            }
        } else {
            $plugin->nagios_exit(CRITICAL, "Peer protocol session name status doesn't match: $peer[2]");
        }   
    } else {
        $plugin->nagios_exit(CRITICAL, "Peer protocol session name doesn't exists: $peer2check.");
    }
} else {
    $plugin->nagios_exit(CRITICAL, "Wrong character for peer provider.");
}
if ($@) { $plugin->nagios_exit(CRITICAL, $@); }
