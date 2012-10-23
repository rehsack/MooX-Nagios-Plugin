package App::Nagios::Plugin::Command::mongo_uptime;

use v5.14;
use strictures;
use Moose;

# extends qw(CLI::App::Perf::Index::Command);
extends qw(MooseX::App::Cmd::Command);
#with 'CLI::App::Perf::Index::Role::AutoHelp', 'CLI::App::Perf::Index::Role::ServiceDB',
#  'MooseX::SimpleConfig',
# 'CLI::App::Perf::Index::Role::FindConfigFile';

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::Crit),
  qw(MooseX::Nagios::Plugin MooseX::Nagios::Plugin::Type::Threshold);

has '+crit' => (
                 isa    => 'Threshold::Time',
                 coerce => 1,
               );

# ABSTRACT: import new performance data for service

sub description
{
    "Checking uptime of mongodb to avoid permanently restarts";
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
      $self->session->get_request( -varbindlist => [ $extapp_base . $found[0] . ".100.5" ] );
    @values = ( int( $resp->{ $extapp_base . $found[0] . ".100.5" } * 1000 * 1000 ) );    # ms -> ns
    push( @values, [ "uptime", $values[0], $self->crit ] );

    $self->message( sprintf( "%ds", $resp->{ $extapp_base . $found[0] . ".100.5" } ) );

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

