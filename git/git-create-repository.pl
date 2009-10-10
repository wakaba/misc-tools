#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use File::Temp qw/tempdir/;

sub x (@) {
  print STDERR join ' ', @_;
  print STDERR "\n";
  system @_;
} # x

sub Path::Class::Dir::v_chdir ($) {
  my $self = shift;
  printf STDERR "cd %s\n", $self->stringify;
  return chdir $self;
} # v_chdir

sub Path::Class::Dir::v_mkpath ($) {
  my $self = shift;
  printf STDERR "mkdir %s\n", $self->stringify;
  return $self->mkpath;
} # v_mkpath

sub Path::Class::Entity::is_special_file_name ($) {
  my $self = shift;
  my $bn = $self->can('basename') ? 'basename' : undef;
  if (defined $bn) {
    return ($bn eq '.' or $bn eq '..');
  } else {
    my $name = $self->stringify;
    return ($name =~ m[/\.\.?\z] or $name eq '.' or $name eq '..');
  }
} # is_special_file_name

my $repos_d;
my $template_d = file(__FILE__)->dir->subdir('template')->absolute;
my $tmp_d = dir(tempdir)->absolute;

my $repo_category = shift;
my $repo_name = shift;
die "Usage: perl $0 repository-category repository-name\n"
    unless $repo_category and $repo_name;

if ($repo_category eq 'pub' or $repo_category eq 'melon') {
  $repos_d = dir('/git')->absolute;
} elsif ($repo_category eq 'test') {
  $repos_d = dir('/tmp')->absolute;
} else {
  die "$0: Category $repo_category is not defined\n";
}

my $repo_d = $repos_d->subdir($repo_category)->subdir("$repo_name.git");
if (-d $repo_d) {
  die "$0: $repo_d: There is already a directory\n";
}

$repo_d->v_mkpath;
$repo_d->v_chdir;
x qw/git init --bare/;

$tmp_d->v_chdir;
x qw/git clone/, $repo_d, $repo_name;

my $tmp_copy_d = $tmp_d->subdir($repo_name);
$tmp_copy_d->v_chdir;

while (my $f = $template_d->next) {
  next if $f->is_special_file_name;
  next if $f eq $template_d;
  x 'cp', '-R', $f, $tmp_copy_d;
}

x qw/git add ./;
x qw/git commit -m/, 'New repository';
x qw/git push origin master/;

x qw/chown git.git -R/, $repo_d;

printf STDERR "$0: Created git repository %s\n", $repo_d->stringify;
printf STDERR "Next step: \$ git clone git\@melon:%s\n", $repo_d->stringify;
