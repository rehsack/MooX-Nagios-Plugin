package MooseX::Nagios::Plugin::Fetch::BySnmp;

use v5.14;
use strictures;
use Moose::Role;

# ABSTRACT: nagios plugin role for snmp checks

use Carp qw/croak/;
use Net::SNMP;

use DateTime;
use DateTime::Duration;

with 'MooseX::Nagios::Plugin::Fetch::Remote';

requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)

sub default_remote_port { 161 }

has 'snmp_version' => (
                        traits        => [qw(Getopt)],
                        isa           => 'Str',
                        is            => 'rw',
                        cmd_flag      => 'snmp-version',
                        documentation => 'SNMP protocol version to use (1, 2c, 3)',
                        builder       => 'default_snmp_version',
                        required      => 1,
                      );

sub default_snmp_version { "2c" }

has 'snmp_community' => (
                          traits        => [qw(Getopt)],
                          isa           => 'Str',
                          is            => 'rw',
                          cmd_flag      => 'snmp-community',
                          documentation => 'SNMP community name (versions 1 & 2c)',
                          builder       => 'default_snmp_community',
                          required      => 1,
                        );

sub default_snmp_community { "public" }

# XXX: v3 args ...

has 'session' => (
                   traits   => [qw(NoGetopt)],
                   is       => 'ro',
                   builder  => '_snmp_connect',
                   init_arg => undef,
                   lazy     => 1
                 );

has 'server_type' => (
                       traits   => [qw(NoGetopt)],
                       is       => 'ro',
                       builder  => '_snmp_server_type',
                       init_arg => undef,
                       lazy     => 1
                     );

has 'smart_snmpd_ident' => (
                             traits   => [qw(NoGetopt)],
                             isa      => 'Str',
                             is       => 'ro',
                             default  => 'Smart-SNMPd',
                             init_arg => undef,
                             lazy     => 1
                           );

has 'net_snmpd_ident' => (
                           traits   => [qw(NoGetopt)],
                           isa      => 'Str',
                           is       => 'ro',
                           default  => 'net-snmpd',
                           init_arg => undef,
                           lazy     => 1
                         );

=method _snmp_connect

Connects to specified host on given port using snmp protocol in
given version.

=cut

sub _snmp_connect
{
    my $self = shift;
    return
      Net::SNMP->session(
                          -hostname  => $self->host,
                          -port      => $self->port,
                          -version   => $self->snmp_version,
                          -timeout   => $self->timeout,
                          -retries   => $self->retries,
                          -community => $self->snmp_community,
                        );
}

=method _snmp_server_type

Determines snmpd type by fetching SNMPv2-MIB::sysObjectID.0 (.1.3.6.1.2.1.1.2.0)
and comparing it against known type:

=over 16

=item C<^.1.3.6.1.4.1.36539.>

Smart-SNMPd

=item C<^.1.3.6.1.4.1.8072.>

net-snmpd

=back

=cut

sub _snmp_server_type
{
    my $self        = shift;
    my $sysIdentOid = ".1.3.6.1.2.1.1.2.0";
    my $resp        = $self->session->get_request( -varbindlist => [$sysIdentOid] );
    ( my $sysIdent = $resp->{$sysIdentOid} )
      or croak( "No response from " . $self->host . ":" . $self->port . "querying $sysIdentOid" );
    $sysIdent =~ m/^\.1\.3\.6\.1\.4\.1\.36539\./ and return $self->smart_snmpd_ident;
    $sysIdent =~ m/^\.1\.3\.6\.1\.4\.1\.8072\./  and return $self->net_snmpd_ident;
    return $sysIdent;
}

=method validate_snmpd

Validates snmpd against given list of permitted snmpd's.

  $self->validate_snmpd( $self->smart_snmpd_ident );
  $self->validate_snmpd( $self->net_snmpd_ident );

Throws exception when found snmpd is not in list of permitted snmpd's.

Returns found snmpd.

=cut

sub validate_snmpd
{
    my ( $self, @valid_snmpds ) = @_;

    scalar @valid_snmpds == 1
      and ref( $valid_snmpds[0] ) eq "ARRAY"
      and @valid_snmpds = @{ $valid_snmpds[0] };

    my $session = $self->session;
    $self->server_type ~~ @valid_snmpds
      or die 'SNMP daemon '
      . $self->server_type
      . ' not supported, please install '
      . join( ", ", @valid_snmpds );

    return 1;
}

=method find_ext_app

Smart-SNMPd feature: external plugin mib.

External objects mib looks like:

    LAST_UPDATE_EXTERNAL_COMMAND	.1	UINT64
    LAST_STARTED_EXTERNAL_COMMAND	.2	UINT64
    LAST_FINISHED_EXTERNAL_COMMAND	.3	UINT64
    EXTERNAL_COMMAND_COMMAND_PATH	.4	STR
    EXTERNAL_COMMAND_COMMAND_LINE	.5	STR
    EXTERNAL_COMMAND_USER		.6	STR
    EXTERNAL_COMMAND_LAST_EXIT_CODE	.7	INT
    EXTERNAL_COMMAND_LAST_EXIT_SIGNAL	.8	INT
    EXTERNAL_COMMAND_ERROR_CODE		.9	INT
    EXTERNAL_COMMAND_ERROR_MESSAGE	.10	STR
    EXTERNAL_COMMAND_DATA		.100	STRUCT

Scans external objects mib for specified pattern.

Expects parameters:

=over 8

=item C<ident>

Plugin name to search for

=item C<match>

Regular expression matching fetched value

=item C<match_oid>

Object Identifier below each external object needed to match (.1 .. .10).
Defaults to C<.5> (I<EXTERNAL_COMMAND_COMMAND_LINE>) if omitted.

=item C<update_age>

Proved that the timestamp in C<.1> (I<LAST_UPDATE_EXTERNAL_COMMAND>) is not
older than C<update_age> seconds.  Defaults to C<5min> if omitted.

=back

In scalar context the oid below I<SM_EXTERNAL_COMMANDS>
(C<.1.3.6.1.4.1.36539.20>) matched specified expression is returned.

In list context this method returns the values for the oid below
I<SM_EXTERNAL_COMMANDS> as first entry and the fetched values for the
oids '.1' .. '.10' below SM_EXTERNAL_COMMANDS.$found are returned
with path stripped:
  [
    $found,
    {
	'.1' => ...,
	'.2' => ...,
	...
    }
  ]

If the desired external object isn't found, an exception is thrown.

=cut

sub find_ext_app
{
    my ( $self, $params ) = @_;

    defined( $params->{ident} ) or croak 'Missing $params->{ident}';
    defined( $params->{match} ) or croak 'Missing $params->{match}';

    $params->{match_oid}  //= ".5";
    $params->{update_age} //= 5 * 60;

    my $session = $self->session;
    $self->validate_snmpd( $self->smart_snmpd_ident );

    my $extapp_base       = ".1.3.6.1.4.1.36539.20.";
    my @extapp_query_vals = qw(.1 .2 .3 .4 .5 .6 .7 .8 .9 .10);
    my @found;
    for my $extapp ( 1 .. 255 )
    {
        my $extapp_oid = $extapp_base . $extapp;
        my $resp =
          $session->get_request( -varbindlist => [ map { $extapp_oid . $_ } @extapp_query_vals ] );
        $resp =
          { map { ( my $oid = $_ ) =~ s/^\Q$extapp_oid\E//; $oid => $resp->{$_} } keys %$resp };
        $resp->{ $params->{match_oid} } =~ $params->{match}
          and @found = ( $extapp, $resp )
          and last;
    }

    @found or die "Cannot find external mib for " . $params->{ident};

    my $resp = $session->get_request( -varbindlist => [qw(.1.3.6.1.4.1.36539.10.1.1)] );
    my $ea_updated = DateTime->from_epoch( epoch => $found[1]->{'.1'} );
    my $sm_updated = DateTime->from_epoch( epoch => $resp->{'.1.3.6.1.4.1.36539.10.1.1'} );
    my $diff       = $sm_updated - $ea_updated;
    my $wanted = DateTime::Duration->new( seconds => $params->{update_age} );
    if ( DateTime::Duration->compare( $diff, $wanted, $sm_updated ) > 0 )
    {
        $ea_updated == DateTime->from_epoch( epoch => 0 )
          and die $params->{ident} . " has never been updated";
        my %deltas = $diff->deltas;
        my $ages = join( " ", map { $deltas{$_} . " " . $_ } qw(months days minutes seconds) );
        die $params->{ident} . " has not been updated since $ages",;
    }

    return wantarray ? @found : $found[0];
}

1;
