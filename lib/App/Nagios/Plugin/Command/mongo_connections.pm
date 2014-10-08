package App::Nagios::Plugin::Command::mongo_connections;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooX::Nagios::Plugin::Fetch::MongoBySnmp MooX::Nagios::Plugin::Approve::WarnCrit),
  qw(MooX::Nagios::Plugin MooX::Nagios::Plugin::Type::Threshold);

has '+warn' => (
    isa    => 'Threshold::Relative',
    coerce => 1,
);
has '+crit' => (
    isa    => 'Threshold::Relative',
    coerce => 1,
);

# ABSTRACT: plugin to check connection limit of mongodb instance

=method description

Returns plugin's short description for building help/usage page by L<App::Cmd>.

=cut

sub description
{
    "Checking connection limit of mongodb instance";
}

=method fetch

Fetches the connection statistics from smart-snmpd plugin for mongodb.

Mib below C<.1.3.6.1.4.1.36539.20.$plugin_id.100>:

    CONNECTIONS		.12	STRUCT
    CONNECTIONS.CURRENT	.12.1	UINT64
    CONNECTIONS.AVAIL	.12.2	UINT64

Returns the percentual available connections.

Following perfomance data is additionally generated:

=over 4

=item *

C<connections> 3-tuple of percentual current connections, warn threshold,
critical threshold.

=item *

C<current> 3-tuple of current, available and total amount of connections

=back

=cut

sub fetch
{
    my ($self) = @_;
    my @values;

    my @connections_oids = map { join( ".", $self->mongo_instance_oid, $_ ) } qw(100.12.1 100.12.2);
    my $resp = $self->session->get_request( -varbindlist => \@connections_oids );
    $resp or return;
    $resp = { map { ( my $oid = $_ ) =~ s/^.*?(\d+)$/$1/; $oid => $resp->{$_} } keys %$resp };
    my @conn = ( $resp->{1}, $resp->{2}, $resp->{1} + $resp->{2} );
    push( @values, Threshold::Relative->new( int( 100 * $conn[0] / $conn[2] ) ) );
    push( @values, [ "connections", $values[0], $self->warn, $self->crit ] );
    push( @values, [ "current", @conn ] );

    $self->message( sprintf( "%d of %d (%2.1f%%) connections", $conn[0], $conn[2], 100 * $conn[0] / $conn[2] ) );

    return \@values;
}

1;
