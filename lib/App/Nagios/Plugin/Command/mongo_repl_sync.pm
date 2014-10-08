package App::Nagios::Plugin::Command::mongo_repl_sync;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooX::Nagios::Plugin::Fetch::MongoBySnmp MooX::Nagios::Plugin::Approve::WarnCrit), qw(MooX::Nagios::Plugin);

# ABSTRACT: plugin to check synchronisation lag of mongodb replicata set

has '+crit' => (
    isa    => 'Threshold::Time',
    coerce => 1,
);

has '+warn' => (
    isa    => 'Threshold::Time',
    coerce => 1,
);

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

When more than one host is primary, an exception is thrown.

Returns the opsync timestamp difference from checked node to primary node,
the warning and the critical threshold.

Following performance data is appended:

=over 4

=item *

C<optime_$nodename> for checked host containing last opsync timestamp
and operations counts

=item *

C<opsync_$nodename> for checked host containing opsync timestamp difference
to primary node, the warning and the critical threshold.

=back

=cut

sub fetch
{
    my ($self) = @_;
    my @values;

    my $replset_base_oid     = join( ".", $self->mongo_instance_oid, "100.20" );
    my $replset_tbl_base_oid = join( ".", $replset_base_oid,         "7.1" );
    my $resp = $self->session->get_table( -baseoid => $replset_tbl_base_oid );
    $resp or return;
    $resp = {
        map { ( my $oid = $_ ) =~ s/^\Q$replset_tbl_base_oid\E\.//; $oid => $resp->{$_} }
          keys %$resp
    };
    my @repl;

    foreach my $oid ( keys %$resp )
    {
        my ( $col, $row ) = split( qr/\./, $oid );
        my $val = $resp->{$oid};
        $repl[$row][$col] = $val;
    }
    shift @repl;

    $resp = $self->session->get_request( -varbindlist => [ map { join( ".", $replset_base_oid, $_ ) } qw(2 3 4 5) ] );
    $resp or return;
    $resp =
      { map { ( my $oid = $_ ) =~ s/^\Q$replset_base_oid\E\.//; $oid => $resp->{$_} } keys %$resp };

    my ( $me, $master ) = @$resp{ '4', '5' };
    my @primaries   = grep { $_ and $_->[2] eq $master } @repl;
    my @secondaries = grep { $_ and $_->[5] eq "SECONDARY" } @repl;
    scalar(@primaries) != 1
      and die "Amount of primaries != 1 - " . join( ", ", map { $_->[2] } @primaries );

    # find me
    my $me_set = ( grep { $_->[2] eq $me } @repl )[0];
    $me_set or return;
    $me_set->[7] //= 0;
    $me_set->[2] =~ s/\W/_/g;

    @values = (
        Threshold::Time->new_with_params(
            value => $primaries[0][7] - $me_set->[7],
            unit  => "ms"
        )
    );
    push(
        @values,
        [
            "opsync_" . $me_set->[2],
            Threshold::Time->new_with_params(
                value => $primaries[0][7] - $me_set->[7],
                unit  => "ms"
            ),
            $self->warn->update_unit( unit => "ms" ),
            $self->crit->update_unit( unit => "ms" )
        ],
        [
            "optime_" . $me_set->[2],
            Threshold::Time->new_with_params(
                value => $me_set->[7],
                unit  => "ms"
            ),
            $me_set->[8] // 0
        ]
    );

    $self->message( sprintf( '%d operations last %sms since sync', $me_set->[8] // 0, $primaries[0][7] - $me_set->[7] ) );

    return \@values;
}

1;
