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

sub approve
{
    my ( $self, @values ) = @_;

    my $value = shift @values;
    $value < $self->warn or return $self->warning(@values);

    return;
}

1;
