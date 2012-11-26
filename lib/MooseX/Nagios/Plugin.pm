package MooseX::Nagios::Plugin;

use strictures;
use Moose::Role;

# ABSTRACT: Moose extensions to build nagios plugins

requires 'approve';
requires 'fetch';
requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)

has 'alarm_timeout' => (
                         traits        => [qw(Getopt)],
                         isa           => 'Int',
                         is            => 'rw',
                         cmd_flag      => 'alarm-timeout',
                         documentation => 'alarm timeout in seconds',
                         builder       => 'default_alarm_timeout',
                         required      => 1,
                       );

sub default_alarm_timeout { 45 }

has 'plugin_name' => (
                       traits   => [qw(NoGetopt)],
                       isa      => 'Str',
                       is       => 'ro',
                       init_arg => undef,
                       builder  => '_plugin_name',
                       required => 1,
                     );

=method _plugin_name

builder for attribute C<plugin_name>. Returns the last part
of the package name.

=cut

sub _plugin_name
{
    my $class = $_[0];
    ref($class) and $class = ref($class);
    $class =~ s/^(\w+::)+//;
    $class;
}

has 'message' => (
                   traits   => [qw(NoGetopt)],
                   isa      => 'Str',
                   is       => 'rw',
                   init_arg => undef,
                 );

my %nagios_codes = (
                     OK        => 0,
                     WARNING   => 1,
                     CRITICAL  => 2,
                     UNKNOWN   => 3,
                     DEPENDENT => 4,
                   );

sub _fmt_perf_data
{
    my ( $self, @values ) = @_;
    my @perf_data;

    @values or return;

    foreach my $item (@values)
    {
        my @perf_value = @$item;
        my $perf_name  = shift @perf_value;
        $perf_name =~ m/[^_a-zA-Z0-9]/ and $perf_name = "\"$perf_name\"";
        push( @perf_data, "$perf_name=" . join( ";", @perf_value ) );
    }

    return join( " ", @perf_data );
}

sub _handle_output_return
{
    my ( $self, $code, @values ) = @_;

    my $msg = sprintf( "%s %s", uc $self->plugin_name, $code );
    $self->message and $msg = join( " - ", $msg, $self->message );

    @values and $msg = join( "|", $msg, $self->_fmt_perf_data(@values) );

    print "$msg\n";
    return $nagios_codes{$code};
}

=method ok

Prints out the check result "OK" and the check message, if any.
If permitted (TODO) and available, performance data is displayed
separated from status output by "|" and among each other by " ".

Returns the nagios status code for OK - 0.

=cut

sub ok
{
    my ( $self, @values ) = @_;
    $self->_handle_output_return( "OK", @values );
}

=method warning

Prints out the check result "WARNING" and the check message, if any.
If permitted (TODO) and available, performance data is displayed
separated from status output by "|" and among each other by " ".

Returns the nagios status code for WARNING - 1.

=cut

sub warning
{
    my ( $self, @values ) = @_;
    $self->_handle_output_return( "WARNING", @values );
}

=method critical

Prints out the check result "CRITICAL" and the check message, if any.
If permitted (TODO) and available, performance data is displayed
separated from status output by "|" and among each other by " ".

Returns the nagios status code for CRITICAL - 2.

=cut

sub critical
{
    my ( $self, @values ) = @_;
    $self->_handle_output_return( "CRITICAL", @values );
}

=method unknown

Prints out the check result "UNKNOWN" and the check message, if any.
If permitted (TODO) and available, performance data is displayed
separated from status output by "|" and among each other by " ".

Returns the nagios status code for UNKNOWN - 3.

=cut

sub unknown
{
    my ( $self, @values ) = @_;
    $self->_handle_output_return( "UNKNOWN", @values );
}

=method execute

Provides the execute method required by App::Cmd. It executes the
C<fetch> method provided by the plugin encompassed by an alarm timer.

The fetched values are passed to the approve method which is either
provided by specific roles (eg. L<MooseX::Nagios::Plugin::Approve::Warn>)
or by the command plugin, if individual checks are required.

Any catched exception leads directly to an UNKNOWN state.

Returns the nagios status code.

=cut

sub execute
{
    my ( $self, $opt, $args ) = @_;

    my ( @values, @errlst );

    local $SIG{ALRM} = sub { die "alarm\n" };
    local $SIG{__DIE__} = sub { push( @errlst, @_ ) };
    eval {
        $self->alarm_timeout and alarm( $self->alarm_timeout );

        my $fetched = $self->fetch();
        @values = ref($fetched) ? @$fetched : ($fetched);
    };
    alarm(0);

    if (@errlst)
    {
        $self->message( $errlst[-1] );
        "alarm" ~~ @errlst and $self->message("alarm timeout");
        return $self->unknown();
    }

    $self->approve(@values) or $self->ok( @values[ 1 .. $#values ] );
}

1;
