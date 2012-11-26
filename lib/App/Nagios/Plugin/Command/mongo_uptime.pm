package App::Nagios::Plugin::Command::mongo_uptime;

use v5.14;
use strictures;
use Moose;

extends qw(MooseX::App::Cmd::Command);

with qw(MooseX::Nagios::Plugin::Fetch::BySnmp MooseX::Nagios::Plugin::Approve::Crit),
  qw(MooseX::Nagios::Plugin MooseX::Nagios::Plugin::Type::Threshold);

has '+crit' => (
                 isa    => 'Threshold::Time',
                 coerce => 1,
               );

# ABSTRACT: plugin to check uptime of mongodb to avoid permanently restarts

=method description

Returns plugin's short description for building help/usage page by L<App::Cmd>.

=cut

sub description
{
    "Checking uptime of mongodb to avoid permanently restarts";
}

=method fetch

Fetches the mongodb uptime from smart-snmpd plugin for mongodb.

Mib below C<.1.3.6.1.4.1.36539.20.$plugin_id.100>:

    UPTIME	.5	UINT64

Returns the uptime in nanoseconds.

Following performance data is additionally delivered:

=over 4

=item *

C<uptime> 2-tuple of uptime and critical threshold.

=back

TODO: setup the returned uptime value by specifying the unit, do not make
assumptions about internal units of Threshold::Time.

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

    my $uptime_oid = $extapp_base . $found[0] . ".100.5";
    my $resp = $self->session->get_request( -varbindlist => [$uptime_oid] );

    defined $resp->{$uptime_oid} or return;

    my $uptime = $resp->{$uptime_oid};
    push(
          @values,
          Threshold::Time->new_with_params(
                                            value => $uptime,
                                            unit  => "ms"
                                          )
        );
    push( @values, [ "uptime", $values[0], $self->crit ] );

    $self->message( sprintf( "%ds", $resp->{$uptime_oid} ) );

    return \@values;
}

1;
