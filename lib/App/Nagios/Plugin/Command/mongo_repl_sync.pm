package App::Nagios::Plugin::Command::mongo_repl_sync;

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
    "Checking synchronisation lag of mongodb replicata set";
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
    # @values = (int($resp->{$extapp_base . $found[0] . ".100.99.3"} / (1000*1000)));
    # push(@values, ["querytime", $values[0], $self->warn, $self->crit]);
    $resp = { map { ( my $oid = $_ ) =~ s/^\Q$baseoid\E\.//; $oid => $resp->{$_} } keys %$resp };
    my @repl;
    foreach my $oid ( keys %$resp )
    {
        my ( $col, $row ) = split( qr/\./, $oid );
        my $val = $resp->{$oid};
        $repl[$row][$col] = $val;
    }
    shift @repl;

    $baseoid = $extapp_base . $found[0] . ".100.20.";
    $resp    = $self->session->get_request( -varbindlist => [ map { $baseoid . $_ } qw(2 3 4 5) ] );
    $resp    = { map { ( my $oid = $_ ) =~ s/^\Q$baseoid\E//; $oid => $resp->{$_} } keys %$resp };

    my ( $me, $master ) = @$resp{ '4', '5' };
    my @primaries = grep { $_ and $_->[2] eq $master } @repl;
    my @secondaries = grep { $_ and $_->[2] ne $master and $_->[5] ne "ARBITER" } @repl;
    scalar(@primaries) != 1
      and die "Amount of primaries != 1 - " . join( ", ", map { $_->[2] } @primaries );
    scalar(@secondaries) != 1
      and die "Amount of secondaries != 1 - " . join( ", ", map { $_->[2] } @secondaries );

    push( @values, [ @primaries, @secondaries ] );
    foreach my $rh (@repl)
    {
        if ( defined( $rh->[7] ) )
        {
            my $perf_name = 'optime_' . $rh->[2];
            $perf_name =~ s/\W/_/g;
            push( @values, [ $perf_name, $rh->[7], $rh->[8] // 0 ] );
        }

        if ( defined( $rh->[10] ) )
        {
            my $perf_name = 'last_heartbeat_' . $rh->[2];
            $perf_name =~ s/\W/_/g;
            push( @values, [ $perf_name, $rh->[10] ] );
        }
    }

    $self->message(
                    sprintf(
                             '%d operations last %sms since sync',
                             $secondaries[0][8],
                             $secondaries[0][10] - $secondaries[0][7]
                           )
                  );

    return \@values;
}

sub approve
{
    my ( $self, @values ) = @_;

    my ( $primary, $secondary ) = @{ shift @values };
    if ( $secondary->[8] )
    {
        my $heartbeat_diff = $secondary->[10] - $secondary->[7];
        my $optime_diff    = $primary->[7] - $secondary->[7];

        $heartbeat_diff > $self->crit
          and return $self->critical(@values);

        $optime_diff > $self->crit
          and return $self->critical(@values);

        $heartbeat_diff > $self->warn
          and return $self->warning(@values);

        $optime_diff > $self->warn
          and return $self->warning(@values);
    }

    return;
}

# nagios check | W | C |
# check connection | 1s | 2s |
# replication lag | 15s | 30s |
# replset status | 0,3,5 | 4,6,7 | OK = 1,2,7
# % open connections| 70% | 80% |
# % lock time | 5% | 10% |
# queries per second| 256 | 512 |

1;

