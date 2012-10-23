package MooseX::Nagios::Plugin::Fetch::Remote;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role for remote checks

requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)

has 'host' => (
                traits        => [qw(Getopt)],
                isa           => 'Str',
                is            => 'rw',
                documentation => 'name or ip address of remote host',
                required      => 1,
              );

has 'port' => (
                traits        => [qw(Getopt)],
                isa           => 'Int',
                is            => 'rw',
                documentation => 'port address of remote service',
                builder       => 'default_remote_port',
                required      => 1,
              );

has 'timeout' => (
                   traits        => [qw(Getopt)],
                   isa           => 'Int',
                   is            => 'rw',
                   documentation => 'network timeout in seconds',
                   builder       => 'default_network_timeout',
                   required      => 1,
                 );

sub default_network_timeout { 5 }

has 'retries' => (
                   traits        => [qw(Getopt)],
                   isa           => 'Int',
                   is            => 'rw',
                   documentation => 'retry count',
                   builder       => 'default_retry_count',
                   required      => 1,
                 );

sub default_retry_count { 1 }

1;
