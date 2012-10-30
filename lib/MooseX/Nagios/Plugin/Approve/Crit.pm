package MooseX::Nagios::Plugin::Approve::Crit;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks with critical

requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)
requires 'critical';

has 'crit' => (
                traits        => [qw(Getopt)],
                isa           => 'Int',
                is            => 'rw',
                documentation => 'crit threshold',
                required      => 1,
              );

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<crit> attribute,
invoking $self->critical otherwise.

=cut

sub approve
{
    my ( $self, @values ) = @_;

    my $value = shift @values;
    $self->crit > $value or return $self->critical(@values);

    return;
}

1;
