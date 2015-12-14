# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use Wanage::URL;
use Wanage::HTTP;
use Warabe::App;
use Promised::Command;
use JSON::PS;
use Data::Dumper;

$ENV{LANG} = 'C';
$ENV{TZ} = 'UTC';

my $RootPath = path (__FILE__)->parent->parent->absolute;

return sub {
  delete $SIG{CHLD} if defined $SIG{CHLD} and not ref $SIG{CHLD}; # XXX

  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);

  return $app->execute_by_promise (sub {
    my $path = $app->path_segments;

    $http->set_response_header
        ('Strict-Transport-Security' => 'max-age=2592000; includeSubDomains; preload');

    if (@$path == 1 and $path->[0] eq 'harusame') {
      return $app->send_error (405) unless $app->http->request_method eq 'POST';
      my $cmd = Promised::Command->new ([
        $RootPath->child ('local/harusame/harusame'),
        '--lang' => $app->bare_param ('lang') // '',
      ]);
      $cmd->wd ($RootPath->child ('local/harusame'));
      $cmd->stdin ($app->http->request_body_as_ref // \'');
      $cmd->stdout (\my $stdout);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        $app->http->set_status (400, reason_phrase => $_[0])
            unless $_[0]->exit_code == 0;
        $app->http->send_response_body_as_ref (\$stdout);
        $app->http->close_response_body;
      })->catch (sub {
        warn $_[0];
        return $app->send_error (500);
      });
    } elsif (@$path == 1 and $path->[0] eq 'anolis') {
      return $app->send_error (405) unless $app->http->request_method eq 'POST';
      my $cmd = Promised::Command->new ([
        'anolis',
      ]);
      $cmd->wd ($RootPath);
      $cmd->stdin ($app->http->request_body_as_ref // \'');
      $cmd->stdout (\my $stdout);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        $app->http->set_status (400, reason_phrase => $_[0])
            unless $_[0]->exit_code == 0;
        $app->http->send_response_body_as_ref (\$stdout);
        $app->http->close_response_body;
      })->catch (sub {
        warn $_[0];
        return $app->send_error (500);
      });
    } elsif (@$path == 1 and $path->[0] eq 'json2perl') {
      return $app->send_error (405) unless $app->http->request_method eq 'POST';
      my $ref = $app->http->request_body_as_ref // \'';
      my $perl = json_bytes2perl $$ref;
      if (not defined $perl and not $$ref =~ /^\s*null\s*$/) {
        return $app->send_error (400, reason_phrase => 'Bad input');
      } else {
        local $Data::Dumper::Sortkeys = 1;
        my $dumped = Dumper $perl;
        $dumped =~ s/^\$VAR1\s*=\s*//;
        $dumped =~ s/\s*;\s*$//;
        $app->http->set_response_header
            ('Content-Type' => 'text/perl; charset=utf-8');
        $app->http->send_response_body_as_text ($dumped);
        return $app->http->close_response_body;
      }
    }

    return $app->send_error (404);
  });
};

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
