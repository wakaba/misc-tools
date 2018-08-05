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
    } elsif (@$path == 1 and
             ($path->[0] eq 'webhacc' or
              $path->[0] eq 'webhacc.json')) {
      return $app->send_error (405) unless $app->http->request_method eq 'POST';
      my @args;
      push @args, '--json' if $path->[0] eq 'webhacc.json';
      my $url = $app->text_param ('url');
      push @args, $url if defined $url and length $url;
      for (qw(check-error-response dtd-validation image-viewable
              noscript show-dump show-inner-html xml-external-entities
              help version specs)) {
        push @args, "--$_" if $app->bare_param ($_);
      }
      for (qw(content-type input)) {
        my $v = $app->text_param ($_);
        push @args, "--$_" => $v if defined $v;
      }
      my $cmd = Promised::Command->new ([
        $RootPath->child ('local/webhacc-cli/webhacc'), @args
      ]);
      $cmd->wd ($RootPath->child ('local/webhacc-cli'));
      $cmd->stdin ($app->http->request_body_as_ref // \'');
      $cmd->stdout (\my $stdout);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        $app->http->set_status (400, reason_phrase => $_[0])
            unless $_[0]->exit_code == 0 or $_[0]->exit_code == 1;
        if ($path->[0] eq 'webhacc.json') {
          $app->http->add_response_header
              ('Content-Type' => 'application/json; charset=utf-8');
        } else {
          $app->http->add_response_header
              ('Content-Type' => 'text/plain; charset=utf-8');
        }
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
      $cmd->stderr (\my $stderr);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        if ($_[0]->exit_code == 0) {
          $app->http->send_response_body_as_ref (\$stdout);
        } else {
          $app->http->set_status (400, reason_phrase => $_[0]);
          $app->http->send_response_body_as_ref (\"$_[0]");
          $app->http->send_response_body_as_ref (\$stdout);
          $app->http->send_response_body_as_ref (\$stderr);
        }
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
