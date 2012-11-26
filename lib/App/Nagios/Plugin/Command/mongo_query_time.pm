package App::Nagios::Plugin::Command::mongo_query_time;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::WarnCrit),
  qw(MooseX::Nagios::Plugin);

# ABSTRACT: plugin to check query time of snmpd plugin for mongodb

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
    "Checking query time of snmpd plugin for mongodb";
}

=method fetch

Fetches the query time from smart-snmpd plugin for mongodb.

Mib below C<.1.3.6.1.4.1.36539.20.$plugin_id.100>:

    QUERYTIME		.99	STRUCT
    QUERYTIME.USER	.99.1	UINT64
    QUERYTIME.SYSTEM	.99.2	UINT64
    QUERYTIME.WALL	.99.3	UINT64

Returns the overall query time for fetching all plugin delivered values
in seconds and the overall querytime, warn threshold and crit threshold
as I<querytime> performance data.

TODO: update warn/crit being time-threshold

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

    my $query_time_oid = $extapp_base . $found[0] . ".100.99.3";
    my $resp = $self->session->get_request( -varbindlist => [$query_time_oid] );

    defined $resp->{$query_time_oid} or return;

    my $query_time = $resp->{$query_time_oid};
    @values = Threshold::Time->new_with_params( value => $query_time,
                                                unit  => "ns" );
    push( @values, [ "querytime", $values[0], $self->warn, $self->crit ] );

    $self->message( sprintf( "%0.6fms", $resp->{$query_time_oid} / ( 1000 * 1000 ) ) );

    return \@values;
}

1;
