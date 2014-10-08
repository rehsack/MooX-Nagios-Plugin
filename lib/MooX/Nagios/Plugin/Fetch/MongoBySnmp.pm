package MooX::Nagios::Plugin::Fetch::MongoBySnmp;

use v5.14;
use strictures;
use Moose::Role;
use Moose::Util::TypeConstraints;

use Carp qw/croak/;

# ABSTRACT: nagios plugin role for finding mongodb plugin on snmpd

with 'MooX::Nagios::Plugin::Fetch::BySnmp';

requires qw(help_flag);    # ensure MooseX::Getopt is loaded >:-)

has mongo_instance => (
    traits        => [qw(Getopt)],
    isa           => enum( [qw(replica_set router config_server)] ),
    is            => 'rw',
    cmd_flag      => 'mongo-instance',
    documentation => 'defines the instance of the mongodb (replica_set, router or config_server)',
    required      => 0,
    predicate     => 'has_mongo_instance',
);

has mongo_plugin_match => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_flag      => 'mongo-plugin-match',
    documentation => 'specifies regular expression which shall match .1.3.6.1.4.1.36539.20.$i.5',
    required      => 0,
    builder       => '_mongo_plugin_match',
    lazy          => 1,
);

has mongo_instance_oid => (
    traits   => [qw(NoGetopt)],
    isa      => 'Str',
    is       => 'ro',
    builder  => '_mongo_instance_oid',
    init_arg => undef,
    lazy     => 1
);

my %mongo_instance_ports = (
    'router'        => 27017,
    'replica_set'   => 27018,
    'config_server' => 27019,
);

sub _mongo_instance_port
{
    defined $_[1]
      and defined $mongo_instance_ports{ $_[1] }
      and return $mongo_instance_ports{ $_[1] };
    croak('$obj->_mongo_instance_port(router|replica_set|config_server)');
}

sub _mongo_plugin_match
{
    my $self = shift;
    my $port = $self->_mongo_instance_port( $self->has_mongo_instance ? $self->mongo_instance : "replica_set" );
    return "^/(?:[^/]+/)*mongodb-stats.*dsn.*:$port\$";
}

sub _mongo_instance_oid
{
    my $self  = shift;
    my $match = $self->mongo_plugin_match;
    my @found = $self->find_ext_app(
        {
            ident     => "MongoDB-Instance",
            match     => qr/$match/,
            match_oid => ".5",
        }
    );
    return join( ".", $self->external_app_base_oid, $found[0] );
}

1;
