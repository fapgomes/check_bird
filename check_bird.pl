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
    print "DEBUG: $birdc show protocols $peer2check\n" if $plugin->opts->debug;
    # see the details for the peer provider
    my @peer = qx/$birdc show protocols $peer2check/;
    print Dumper \@peer if $plugin->opts->debug;
    # remove headers from command line
    #shift @peer for 1..2;
    # NOS_ipv4   BGP        ---        up     2020-09-22    Established
    if (defined($peer[2])) {
        print "DEBUG : $peer[2]\n" if $plugin->opts->debug;
        if ($peer[2] =~ m/^[\w\d\_\-]+\s+BGP\s+---\s+(\w+)\s+([\d+\-\.\:]+)\s+(\w+)/) {
            $status = $1;
            $since = $2;
            $info = $3;
            if ($status eq "up") {
                $output = "$peer2check $status since $2 with connection $info";
                print "DEBUG: $birdc show route protocol $peer2check count\n" if $plugin->opts->debug;
                my @routes = qx/$birdc show route protocol $peer2check count/;
                # remove first line 
                #shift @routes;
                print Dumper \@routes if $plugin->opts->debug;

                $routes[1] =~ m/^(\d+) of/;
                # check if i've more than one route...
                if ($1 >= 1) {
                    print "DEBUG: ROUTES: $1\n"if $plugin->opts->debug;
                    $output .= " routes: $1|'established_routes'=$1;;;0";
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
