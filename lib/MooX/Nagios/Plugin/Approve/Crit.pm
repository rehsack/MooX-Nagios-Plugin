package MooX::Nagios::Plugin::Approve::Crit;

use strictures;
use Moo::Role;

use MooX::Options;

our $VERSION = "0.003";

=head1 NAME

MooX::Nagios::Plugin::Approve::Crit - nagios plugin role checks with critical

=head1 DESCRIPTION

=head1 METHODS

=cut

requires 'critical';
requires 'approve';

option crit => (
    is       => 'ro',
    doc      => 'crit threshold',
    required => 1,
);

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<crit> attribute,
invoking $self->critical otherwise.

=cut

around approve => sub {
    my $next  = shift;
    my $self  = shift;
    my $state = $self->$next(@_);

    unless ( defined $state )
    {
        my @values = @_;

        my $value = shift @values;
        defined $value or return $self->unknown("No data received");
        ( $self->crit <=> $value ) <= 0 and return $self->critical(@values);
    }

    return;
};

1;
