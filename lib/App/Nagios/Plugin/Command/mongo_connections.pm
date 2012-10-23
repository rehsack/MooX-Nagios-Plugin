package App::Nagios::Plugin::Command::mongo_connections;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::WarnCrit),
  qw(MooseX::Nagios::Plugin MooseX::Nagios::Plugin::Type::Threshold);

has '+warn' => (
                 isa    => 'Threshold::Relative',
                 coerce => 1,
               );
has '+crit' => (
                 isa    => 'Threshold::Relative',
                 coerce => 1,
               );

# ABSTRACT: import new performance data for service

sub description
{
    "Checking connection limit of mongodb instance";
}

sub fetch
{
    my ($self) = @_;
    my @values;

    my $extapp_base = ".1.3.6.1.4.1.36539.20.";
    my @found = $self->find_ext_app(
                                     {
                                       ident     => "MongoDB-Stats",
                                       match     => qr/mongodb-stats$/,
                                       match_oid => ".4",
                                     }
                                   );

    my $resp =
      $self->session->get_request( -varbindlist =>
               [ $extapp_base . $found[0] . ".100.12.1", $extapp_base . $found[0] . ".100.12.2" ] );
    $resp = { map { ( my $oid = $_ ) =~ s/^.*?(\d+)$/$1/; $oid => $resp->{$_} } keys %$resp };
    my @conn = ( $resp->{1}, $resp->{2}, $resp->{1} + $resp->{2} );
    push( @values, Threshold::Relative->new( int( 100 * $conn[0] / $conn[2] ) ) );
    push( @values, [ "connections", $values[0], $self->warn, $self->crit ] );
    push( @values, [ "current", @conn ] );

    $self->message(
          sprintf( "%d of %d (%2.1f%%) connections", $conn[0], $conn[2], 100 * $conn[0] / $conn[2] )
    );

    return \@values;
}

# nagios check | W | C |
# check connection | 1s | 2s |
# replication lag | 15s | 30s |
# replset status | 0,3,5 | 4,6,8 | OK = 1,2,7
# % open connections| 70% | 80% |
# % lock time | 5% | 10% |
# queries per second| 256 | 512 |

1;

