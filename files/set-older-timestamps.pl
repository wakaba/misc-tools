#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('modules')->subdir ('cmdutils')->subdir ('lib')->stringify;

my $local_d = dir (shift);
die "Usage: get-remote-timestamps | $0 local-path" unless -d $local_d;

while (<>) {
  if (/^(\d+)\s+(.+)/) {
    my $new_time = $1;
    my $path = $2;

    my $f = $local_d->file ($path);
    unless (-f $f) {
      warn "File $f not found\n";
      next;
    }
    
    my $current_time = $f->stat->mtime;
    next if $current_time <= $new_time;

    warn $f->relative;
    warn scalar localtime $current_time;
    warn scalar localtime $new_time;
  }
}
