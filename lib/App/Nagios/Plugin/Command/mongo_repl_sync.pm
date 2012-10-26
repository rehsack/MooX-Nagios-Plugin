package App::Nagios::Plugin::Command::mongo_repl_sync;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::WarnCrit),
  qw(MooseX::Nagios::Plugin);

# ABSTRACT: plugin to check synchronisation lag of mongodb replicata set

=method description

Returns plugin's short description for building help/usage page by L<App::Cmd>.

=cut

sub description
{
    "Checking synchronisation lag of mongodb replicata set";
}

=method fetch

Fetches replication set data from smart-snmpd for mongodb plugin.

Mib below C<.1.3.6.1.4.1.36539.20.$plugin_id.100>:

    REPL				.20		STRUCT
    REPL.IS_MASTER			.20.2		INT
    REPL.IS_SECONDARY			.20.3		INT
    REPL.ME				.20.4		STR
    REPL.PRIMARY			.20.5		STR
    REPL.HOSTS				.20.7		TABLE
    REPL.HOSTS.ENTRIES			.20.7.1		ENTRY
    REPL.HOSTS.ENTRIES.ID		.20.7.1.1	UINT
    REPL.HOSTS.ENTRIES.NAME		.20.7.1.2	STR
    REPL.HOSTS.ENTRIES.HEALTH		.20.7.1.3	STR (FLOAT)
    REPL.HOSTS.ENTRIES.STATE		.20.7.1.4	UINT
    REPL.HOSTS.ENTRIES.STATE_STR	.20.7.1.5	STR
    REPL.HOSTS.ENTRIES.UPTIME		.20.7.1.6	UINT64
    REPL.HOSTS.ENTRIES.OPTIME.TIMESTAMP	.20.7.1.7	UINT64
    REPL.HOSTS.ENTRIES.OPTIME.INC	.20.7.1.8	UINT
    REPL.HOSTS.ENTRIES.PING_MS		.20.7.1.9	UINT64
    REPL.HOSTS.ENTRIES.LAST_HEARTBEAT_MS .20.7.1.10	UINT64

When more than one host is primary or secondary, an exception is
thrown.

Returns an array of rows, containing the rows for the primary
node in index 0 and the rows for the secondary node in index 1.

  [ $primary, $secondary ]

Following performance data is appended:

=over 4

=item *

C<optime_$nodename> for each host having an optime value (PRIMARY, SECONDARY)

=item *

C<last_heartbeat_$nodename> for each host having an last_heartbeat value (SECONDARY, ARBITER)

=back

=cut

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

=method aprove

Individual approve method checking the time difference between
the heartbeat timestamp and the optime timestamp of the secondary
node and the optime timestamp difference between the primary
node and the secondary node.

Both differences must be lower than the warning or critical threshold.

=cut

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

1;
