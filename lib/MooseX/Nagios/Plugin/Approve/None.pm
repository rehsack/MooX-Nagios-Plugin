package MooseX::Nagios::Plugin::Approve::None;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks without value approval

=method approve($prove;@perfdata)

Dummy method to make default execute() method happy. Nothing to
approve will always succeed.

=cut

sub approve { }

1;
