package MooX::Nagios::Plugin::Fetch::FromDB;

use 5.014;
use strictures;
use Moo::Role;
use MooX::Options;

our $VERSION = "0.003";

=head1 NAME

MooX::Nagios::Plugin::Fetch::FromDB - nagios plugin role for database (table/rows) checks

=head1 DESCRIPTION

=head1 METHODS

=cut

use Types::Standard qw(Enum Str);
use Carp qw/croak/;
use DBI;

has connection_info => ( is => "lazy" );

sub _build_connection_info
{
    die "_build_connection_info must be provided by an adapter requesting parameters e.g. from CLI";
}

has db_handle => ( is => "lazy",
    init_arg => undef,
);

sub _build_db_handle
{
    my $self = shift;
    my $ci = $self->connection_info;
    DBI->connect( @$ci{qw(dsn user pass attributes)} ) or die DBI->errstr;
}

1;
