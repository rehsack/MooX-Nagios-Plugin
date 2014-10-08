package MooX::Nagios::Plugin::Fetch::Remote;

use strictures;
use Moo::Role;

use MooX::Options;
use Types::Standard qw(Int Str);

our $VERSION = "0.003";

=head1 NAME

MooX::Nagios::Plugin::Fetch::Remote - nagios plugin role for remote checks

=head1 DESCRIPTION

=head1 METHODS

=cut

option host => (
    isa      => Str,
    is       => 'ro',
    format   => 's',
    doc      => 'name or ip address of remote host',
    required => 1,
);

option port => (
    isa    => Int,
    is     => 'ro',
    format => 'i',
    doc    => 'port address of remote service',
    lazy   => 1,
);

option timeout => (
    isa    => Int,
    is     => 'ro',
    format => 'i',
    doc    => 'network timeout in seconds',
    lazy   => 1,
);

sub _build_timout { 5 }

option retries => (
    isa    => Int,
    is     => 'ro',
    format => 'i',
    doc    => 'retry count',
    lazy   => 1,
);

sub _build_retries { 1 }

1;
