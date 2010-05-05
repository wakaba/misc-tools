#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('modules')->subdir ('cmdutils')->subdir ('lib')->stringify;

my $local_d = dir (shift);
die "Usage: get-remote-timestamps | $0 local-path" unless -d $local_d;

while (<>) {
  if (/^(\d+)\s+(\S+)\s+(.+)/) {
    my $new_time = $1;
    my $remote_sha1 = $2;
    my $path = $3;

    my $f = $local_d->file ($path);
    unless (-f $f) {
      warn "File $f not found\n";
      next;
    }
    
    my $current_time = $f->stat->mtime;
    next if $current_time <= $new_time;

    my ($local_sha1) = `sha1sum ${\quotemeta $f}` =~ /^(\S+)/;
    unless ($local_sha1 eq $remote_sha1) {
      warn "File $f is modified\n";
      next;
    }

    printf STDERR "%s (%s => %s)\n",
        $f->relative,
        scalar localtime $current_time,
        scalar localtime $new_time;
  }
}
