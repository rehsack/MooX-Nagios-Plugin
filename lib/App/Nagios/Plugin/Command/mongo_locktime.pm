package App::Nagios::Plugin::Command::mongo_locktime;

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

# ABSTRACT: plugin to check locking times of mongodb

=method description

Returns plugin's short description for building help/usage page by L<App::Cmd>.

=cut

sub description
{
    "Checking locking times of mongodb";
}

=method fetch

Fetches the global lock statistics from smart-snmpd plugin for mongodb.

Mib below C<.1.3.6.1.4.1.36539.20.$plugin_id.100>:

    GLOBALLOCK			.10	STRUCT
    GLOBALLOCK.TOTALTIME	.10.1	UINT64
    GLOBALLOCK.LOCKTIME		.10.2	UINT64

Returns percentual time in locks (referred to total time).

Following performance data is additionally generated:

=over 4

=item *

C<locktime> 3-tuple consists of percentual lock time, warn threshold and
critical threshold.

=back

=cut

sub fetch
{
    my ($self) = @_;
    my @values;

    my @locktime_oids = map { join( ".", $self->mongo_instance_oid, $_ ) } qw(100.10.1 100.10.2);
    my $resp = $self->session->get_request( -varbindlist => \@locktime_oids );
    $resp or return;
    $resp = { map { ( my $oid = $_ ) =~ s/^.*?(\d+)$/$1/; $oid => $resp->{$_} } keys %$resp };
    my @times = ( $resp->{1}, $resp->{2} );
    push( @values, Threshold::Relative->new( int( 100 * $times[1] / $times[0] ) ) );
    push( @values, [ "locktime", $values[0], $self->warn, $self->crit ] );

    $self->message( sprintf( "%dms of %dms (%2.1f%%) locked", $times[1], $times[0], 100 * $times[1] / $times[0] ) );

    return \@values;
}

1;
