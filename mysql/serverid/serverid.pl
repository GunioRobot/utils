#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

sub int2str {
    my $addr = shift;
    my @r;
    $r[$_] = $addr >> (8 * $_) & 0xff for 0 .. 3;
    join '.', reverse @r;
}

sub str2int {
    my @addr = reverse split /\./, shift;
    my $r;
    $r += $addr[$_] << (8 * $_) for 0 .. 3;
    $r;
}

my $opt_reverse = 0;
GetOptions('reverse' => \$opt_reverse);

die "usage: $0 [-r] ipaddress" unless defined $ARGV[0];
print $opt_reverse ? int2str $ARGV[0] : str2int $ARGV[0];
print "\n";
