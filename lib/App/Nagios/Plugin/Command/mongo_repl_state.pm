package App::Nagios::Plugin::Command::mongo_repl_state;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooX::Nagios::Plugin::Fetch::MongoBySnmp MooX::Nagios::Plugin::Approve::None), qw(MooX::Nagios::Plugin);

# ABSTRACT: plugin to check synchronisation state of mongodb replicata set

=method description

Returns plugin's short description for building help/usage page by L<App::Cmd>.

=cut

sub description
{
    "Checking synchronisation state of mongodb replicata set";
}

=method fetch

Fetches the replication node states from smart-snmpd for mongodb plugin.

Mib below C<.1.3.6.1.4.1.36539.20.$plugin_id.100>:

    REPL			.20		STRUCT
    REPL.HOSTS			.20.7		TABLE
    REPL.HOSTS.ENTRIES		.20.7.1		ENTRY
    REPL.HOSTS.ENTRIES.NAME	.20.7.1.2	STR
    REPL.HOSTS.ENTRIES.STATE	.20.7.1.4	UINT

Returns the fetched hosts table for replica set.

Following performance data is returned additionally:

=over 4

=item *

C<state_$nodename> for each node containing the fetched state or 0.

=back

=cut

sub fetch
{
    my ($self) = @_;
    my @values;

    my $extapp_base = ".1.3.6.1.4.1.36539.20.";
    my @found       = $self->find_ext_app(
        {
            ident     => "MongoDB-Stats",
            match     => qr/mongodb-stats$/,
            match_oid => ".4",
        }
    );

    my $replset_tbl_base_oid = join( ".", $self->mongo_instance_oid, "100.20.7.1" );
    my $resp = $self->session->get_table( -baseoid => $replset_tbl_base_oid );
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

=method aprove

Individual approve method checking the states of each node of the shard.

Following checks are performed:

=over 8

=item OK

Column 4 of fetched row must be in [ 1, 2, 7 ]

=item WARNING

Column 4 of fetched row must be in [ 0, 3, 5, 9 ]

=item CRITICAL

Any other value in column 4 of fetched row

=back

The worst result is reported to caller (if any node is
in warning state, and any other in critical state, critical
is reported).

=cut

sub approve
{
    my ( $self, @values ) = @_;
    my $fn;

    my (@repl) = @{ shift @values };
    foreach my $host (@repl)
    {
        $host->[4] ~~ @ok_states and next;
        $host->[4] ~~ @warn_states and $fn = "warning" and next;
        return $self->critical(@values);
    }

    $fn and return $self->$fn(@values);

    return;
}

1;
