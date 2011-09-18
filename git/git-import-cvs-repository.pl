#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use File::Temp qw/tempdir/;
use lib file (__FILE__)->dir->parent->subdir ('modules')->subdir ('cmdutils')->subdir ('lib')->stringify;
use Command qw/x/;
use Extras::Path::Class;
use Getopt::Long;

my $cvs2git = 'cvs2git';

my @exclude_path;
my @exclude_v_file;
my $from_melon_archive;
my $from_suika_wakaba;
my $container_directory_name;

GetOptions (
  'container-directory-name=s' => \$container_directory_name,
  'exclude-path=s' => sub {
    push @exclude_path, $_[1];
  },
  'exclude-v-path=s' => sub {
    push @exclude_v_file, $_[1];
  },
  'from-melon-archive' => \$from_melon_archive,
  'from-suika-wakaba' => \$from_suika_wakaba,
) or die "Usage: perl $0 [options] cvs-module repository-category repository-name\n";

my $cvs_module = shift;
my $repo_category = shift;
my $repo_name = shift || '';
undef $repo_name unless $repo_name =~ /\A[\w-]+\z/;
die "Usage: perl $0 [options] cvs-module repository-category repository-name\n"
    unless $cvs_module and $repo_category and $repo_name;

my $repos_d;
if ($repo_category =~ m[\A(?:pub|melon)(?:/[\w-]+)?\z]) {
  $repos_d = dir ('/git')->absolute;
} elsif ($repo_category =~ m[\Atest(?:/[\w-]+)?\z]) {
  $repos_d = dir ('/tmp')->absolute;
} else {
  die "$0: Category $repo_category is not defined\n";
}

my $repo_d = $repos_d->subdir ($repo_category)->subdir ("$repo_name.git");
if (-d $repo_d) {
  die "$0: $repo_d: There is already a directory\n";
}

my $root_d = file (__FILE__)->dir->absolute;
my $tmp_d = dir (tempdir)->absolute;
my $tmp_cvs_top_d = $tmp_d->subdir ('cvs');
$tmp_cvs_top_d->v_mkpath;

my @rsync_option;
if (@exclude_path) {
  my $prefix = '/' . [split m[/], $cvs_module]->[-1] . '/';
  @rsync_option = map { ('--exclude' => $prefix . $_) } @exclude_path;
}

x qw[rsync -avz wakaba@suika:/home/cvs/CVSROOT], $tmp_cvs_top_d;

my $parent_d = $tmp_cvs_top_d;
if (defined $container_directory_name) {
  $parent_d = $parent_d->subdir ($container_directory_name);
  $parent_d->v_mkpath;
}

if ($from_melon_archive) {
  x qw[cp -R], q[/data1/cvs/archive/] . $cvs_module, $parent_d;
} elsif ($from_suika_wakaba) {
  x qw[rsync -avz], @rsync_option,
      q[wakaba@suika:/home/wakaba/pub/cvs/] . $cvs_module, $parent_d;
} else {
  x qw[rsync -avz], @rsync_option,
      q[wakaba@suika:/home/cvs/] . $cvs_module, $parent_d;
}

my $options_f = $root_d->file ('cvs2git.options.template');
my $tmp_options_f = $tmp_d->file ('cvs2git.options');

my $cvs_lastname = [split m[/], $cvs_module]->[-1];
my $tmp_cvs_repo_d = $tmp_cvs_top_d->subdir
    ($container_directory_name // $cvs_lastname);
my $tmp_cvs2git_d = $tmp_d->subdir ('cvs2git');
$tmp_cvs2git_d->v_mkpath;

my $options = $options_f->slurp or die "$0: $options_f: $!\n";
$options =~ s/\@\@\@CVSREPOPATH\@\@\@/$tmp_cvs_repo_d/g;
$options =~ s/\@\@\@TMPDIR\@\@\@/$tmp_cvs2git_d/g;
my $file = $tmp_options_f->openw or die "$0: $tmp_options_f: $!\n";
print $file $options;
close $file;

for (@exclude_v_file) {
  my $f = $tmp_cvs_repo_d->file ($_);
  $f->remove if -f $f;
}

x $cvs2git, '--options', $tmp_options_f;

my $tmp_git_repo_d = $tmp_d->subdir ('git');
$tmp_git_repo_d->v_mkpath;
$tmp_git_repo_d->v_chdir;
x qw[git init];

my $tmp_cvs2git_blob_f = $tmp_cvs2git_d->file ('git-blob.dat');
my $tmp_cvs2git_dump_f = $tmp_cvs2git_d->file ('git-dump.dat');
x join (' ', map { quotemeta } 'cat', $tmp_cvs2git_blob_f->stringify, $tmp_cvs2git_dump_f->stringify) .
    ' | git fast-import';
x qw/git checkout/;

x qw/git tag cvs2git/;

my $template_d = $root_d->subdir ('template');
while (my $f = $template_d->next) {
  next if $f->is_special_file_name;
  next if $f eq $template_d;
  x 'cp', '-R', $f, $tmp_git_repo_d;
}
x qw/git add ./;
x qw/git commit -m/, 'Copied files from template',
    '--author', 'git-import-cvs-repository <cvs@suika.fam.cx>';

x qw[git clone --bare .], $repo_d;

$repo_d->v_chdir;
x q{chmod -x hooks/*.sample};
if ($repo_category =~ /^(?:pub|test)/) {
  x qw{git --bare update-server-info};
  x qw{mv hooks/post-update.sample hooks/post-update};
  x qw{chmod u+x hooks/post-update};
}

x qw/chown git.git -R/, $repo_d;

printf STDERR "$0: Created git repository %s\n", $repo_d->stringify;
printf STDERR "Next step: \$ git clone git\@melon:%s\n", $repo_d->stringify;
