package MooseX::Nagios::Plugin::Approve::WarnCrit;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks with warning and critical

with qw(MooseX::Nagios::Plugin::Approve::Warn MooseX::Nagios::Plugin::Approve::Crit);

sub approve
{
    my $self = shift;
    $self->MooseX::Nagios::Plugin::Approve::Crit::approve(@_);
    $self->MooseX::Nagios::Plugin::Approve::Warn::approve(@_);
    return;
}

1;
