#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;

my $remote_path = shift or die "Usage: $0 remote-path\n";
my $remote_host = q[suika];
my $exclude_pattern = qr[(?>^|/)(?>CVS|\.\.?|.*~)(?>$|/)];

my $command = join ' ', map { quotemeta }
    q[ssh], $remote_host,
    map { my $a = $_; $a =~ s/\n/ /g; quotemeta $a }
        qw{perl -MPath::Class -e},
        q{
          my $here = shift;
          dir($here)->recurse(callback => sub {
            return unless -f $_[0];
            my ($sha1) = `sha1sum ${\quotemeta $_[0]}` =~ /^(\S+)/;
            print STDOUT $_[0]->stat->mtime, "\t", $sha1, "\t", $_[0]->relative($here), "\n";
          });
        },
        $remote_path;

my %list;
for (split /\n/, `$command`) {
  my ($mtime, $sha1, $path) = split /\s+/, $_;
  next if $path =~ /$exclude_pattern/o;
  $list{$path} = [$mtime, $sha1];
}

for (sort { $a cmp $b } keys %list) {
  printf "%s\t%s\t%s\n", $list{$_}->[0], $list{$_}->[1], $_;
}
