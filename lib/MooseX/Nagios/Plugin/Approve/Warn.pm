package MooseX::Nagios::Plugin::Approve::Warn;

use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role checks with warning

requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)
requires 'warning';

has 'warn' => (
                traits        => [qw(Getopt)],
                isa           => 'Int',
                is            => 'rw',
                documentation => 'warn threshold',
                required      => 1,
              );

=method approve($prove;@perfdata)

Approves the value in $prove being lower than threshold in I<warn> attribute,
invoking $self->warning otherwise.

=cut

sub approve
{
    my ( $self, @values ) = @_;

    my $value = shift @values;
    $self->warn > $value or return $self->warning(@values);

    return;
}

1;
