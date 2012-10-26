package MooseX::Nagios::Plugin::Approve::WarnCrit;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks with warning and critical

with qw(MooseX::Nagios::Plugin::Approve::Warn MooseX::Nagios::Plugin::Approve::Crit);

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<crit> attribute
and I<warn> attribute, invoking $self->critical or $self->warning otherwise.

=cut

sub approve
{
    my $self = shift;
    $self->MooseX::Nagios::Plugin::Approve::Crit::approve(@_);
    $self->MooseX::Nagios::Plugin::Approve::Warn::approve(@_);
    return;
}

1;
