package MooseX::Nagios::Plugin::Approve::Crit;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks with critical

requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)
requires 'critical';

has 'crit' => (
                traits        => [qw(Getopt ThresholdCmp)],
                isa           => 'Int',
                is            => 'rw',
                documentation => 'crit threshold',
                required      => 1,
                predicate     => 'has_crit',
              );

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<crit> attribute,
invoking $self->critical otherwise.

=cut

sub approve
{
    my ( $self, @values ) = @_;

    my $value = shift @values;
    $self->has_crit
      and ( $self->crit <=> $value ) * $self->meta->get_attribute("crit")->compare_modificator <= 0
      and return $self->critical(@values);

    return;
}

1;
