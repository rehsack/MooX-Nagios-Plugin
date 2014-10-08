package MooX::Nagios::Plugin::Approve::WarnCrit;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks with warning and critical

with qw(MooX::Nagios::Plugin::Approve::Warn MooX::Nagios::Plugin::Approve::Crit);

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<crit> attribute
and I<warn> attribute, invoking $self->critical or $self->warning otherwise.

=cut

sub approve
{
    my $self = shift;
    my $rc;
    $rc = $self->MooX::Nagios::Plugin::Approve::Crit::approve(@_) and return $rc;
    $rc = $self->MooX::Nagios::Plugin::Approve::Warn::approve(@_) and return $rc;
    return;
}

1;
