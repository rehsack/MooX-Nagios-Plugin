package MooX::Nagios::Plugin::Approve::None;

use strictures;
use Moo::Role;

our $VERSION = "0.003";

=head1 NAME

MooX::Nagios::Plugin::Approve::None - nagios plugin role checks without value approval

=head1 DESCRIPTION

=head1 METHODS

=method approve($prove;@perfdata)

Dummy method to make default execute() method happy. Nothing to
approve will always succeed.

=cut

sub approve { }

1;
