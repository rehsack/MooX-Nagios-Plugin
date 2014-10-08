package MooX::Nagios::Plugin::Approve::Warn;

use strictures;
use Moo::Role;

use MooX::Options;

our $VERSION = "0.003";

=head1 NAME

MooX::Nagios::Plugin::Approve::Warn - nagios plugin role checks with warning

=head1 DESCRIPTION

=head1 METHODS

=cut

requires 'warning';
requires 'approve';

option warn => (
    is       => 'ro',
    doc      => 'warn threshold',
    required => 1,
);

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<warn> attribute,
invoking $self->warning otherwise.

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
        ( $self->warn <=> $value ) <= 0 and return $self->warning(@values);
    }

    return;
};

1;
