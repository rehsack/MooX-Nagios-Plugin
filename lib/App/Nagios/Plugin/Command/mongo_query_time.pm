package App::Nagios::Plugin::Command::mongo_query_time;

use v5.14;
use strictures;
use Moose;

# extends qw(CLI::App::Perf::Index::Command);
extends qw(MooseX::App::Cmd::Command);
#with 'CLI::App::Perf::Index::Role::AutoHelp', 'CLI::App::Perf::Index::Role::ServiceDB',
#  'MooseX::SimpleConfig',
# 'CLI::App::Perf::Index::Role::FindConfigFile';

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::WarnCrit),
  qw(MooseX::Nagios::Plugin);

# ABSTRACT: import new performance data for service

sub description
{
    "Checking query time of snmpd plugin for mongodb";
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
      $self->session->get_request( -varbindlist => [ $extapp_base . $found[0] . ".100.99.3" ] );
    @values = ( int( $resp->{ $extapp_base . $found[0] . ".100.99.3" } / ( 1000 * 1000 ) ) );
    push( @values, [ "querytime", $values[0], $self->warn, $self->crit ] );

    $self->message(
        sprintf( "%0.6fms", $resp->{ $extapp_base . $found[0] . ".100.99.3" } / ( 1000 * 1000 ) ) );

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

