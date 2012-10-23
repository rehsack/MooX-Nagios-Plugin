package App::Nagios::Plugin::Command::mongo_repl_state;

use v5.14;
use strictures;
use Moose;

# extends qw(CLI::App::Perf::Index::Command);
extends qw(MooseX::App::Cmd::Command);
#with 'CLI::App::Perf::Index::Role::AutoHelp', 'CLI::App::Perf::Index::Role::ServiceDB',
#  'MooseX::SimpleConfig',
# 'CLI::App::Perf::Index::Role::FindConfigFile';

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::None),
  qw(MooseX::Nagios::Plugin);

# ABSTRACT: import new performance data for service

sub description
{
    "Checking synchronisation state of mongodb replicata set";
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

    my $baseoid = $extapp_base . $found[0] . ".100.20.7.1";
    my $resp = $self->session->get_table( -baseoid => $baseoid );
    $resp = { map { ( my $oid = $_ ) =~ s/^\Q$baseoid\E\.//; $oid => $resp->{$_} } keys %$resp };
    my @repl;
    foreach my $oid ( keys %$resp )
    {
        my ( $col, $row ) = split( qr/\./, $oid );
        my $val = $resp->{$oid};
        $repl[$row][$col] = $val;
    }
    shift @repl;

    push( @values, [@repl] );
    foreach my $rh (@repl)
    {
        my $perf_name = 'state_' . $rh->[2];
        $perf_name =~ s/\W/_/g;
        push( @values, [ $perf_name, $rh->[4] // 0 ] );
    }

    return \@values;
}

my @ok_states = ( 1, 2, 7 );
my @warn_states = ( 0, 3, 5, 9 );

sub approve
{
    my ( $self, @values ) = @_;

    my (@repl) = @{ shift @values };
    foreach my $host (@repl)
    {
        $host->[4] ~~ @ok_states   and next;
        $host->[4] ~~ @warn_states and return $self->warning(@values);
        return $self->critical(@values);
    }

    return;
}

# nagios check | W | C |
# check connection | 1s | 2s |
# replication lag | 15s | 30s |
# replset status | 0,3,5 | 4,6,8 | OK = 1,2,7
# % open connections| 70% | 80% |
# % lock time | 5% | 10% |
# queries per second| 256 | 512 |

1;

