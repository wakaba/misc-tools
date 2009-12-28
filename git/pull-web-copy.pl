#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('modules')->subdir ('cmdutils')->subdir ('lib')->stringify;
use Command qw/x/;
use Extras::Path::Class;

my $git_d = dir (shift);

warn "Updating $git_d...\n";

$git_d->v_chdir;

$ENV{GIT_DIR} = '.git';
x qw/git pull/;
x qw/git submodule update --init/;

warn "\n";
