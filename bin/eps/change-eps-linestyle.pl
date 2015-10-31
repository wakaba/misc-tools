#!/usr/bin/perl
use strict;

use Getopt::Long;
use Pod::Usage;

my $FILE_NAME;
my $NUMBER;
my $COLOR;

GetOptions (
  '--color=s' => \$COLOR,
  '--help' => sub { pod2usage 1 },
  '--file-name=s' => \$FILE_NAME,
  '--number=s' => \$NUMBER,
) or pod2usage 2;
pod2usage 2 unless defined $FILE_NAME;
pod2usage 2 unless defined $NUMBER and $NUMBER =~ /^[0-8]$/;
pod2usage 2 unless defined $COLOR;

my $rgb;
if ($COLOR =~ /^\s*rgb\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)\s*$/) {
  $rgb = [$1, $2, $3];
} elsif ($COLOR =~ /^\s*#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})\s*$/) {
  $rgb = [hex $1, hex $2, hex $3];
} elsif ($COLOR =~ /^\s*#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])\s*$/) {
  $rgb = [hex $1, hex $2, hex $3];
} else {
  pod2usage 2;
}

open my $rfile, '<', $FILE_NAME or die "$0: $FILE_NAME: $!";
open my $wfile, '>', "$FILE_NAME.tmp" or die "$0: $FILE_NAME.tmp: $!";
binmode $rfile;
binmode $wfile;

my $replaced;

while (<$rfile>) {
  if (m<^(/LT$NUMBER\s*\{\s*PL\s*\[)([^]]*)\]\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*([^}]*)(\}\s+def)$>) {
    my ($r, $g, $b) = ($3, $4, $5);
    ($r, $g, $b) = @$rgb;
    $replaced = 1;
    print $wfile "$1$2] $r $g $b $6$7\n";
  } else {
    print $wfile $_;
  }
}

close $rfile;
close $wfile;

if ($replaced) {
  rename "$FILE_NAME.tmp" => $FILE_NAME or die "$0: $FILE_NAME: $!";
} else {
  die "Linetype $NUMBER is not found\n";
}
