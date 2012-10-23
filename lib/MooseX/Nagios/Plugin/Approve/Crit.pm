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

sub approve
{
    my ( $self, @values ) = @_;

    my $value = shift @values;
    $value < $self->crit or return $self->critical(@values);

    return;
}

1;
