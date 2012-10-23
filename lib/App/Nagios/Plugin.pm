package App::Nagios::Plugin;

use strictures;
use Moose;
# use Moose::Util qw(ensure_all_roles);

extends qw(MooseX::App::Cmd);

# ABSTRACT: Application Performance Index CLI

#around plugin_for => sub {
#    my ( $orig, $self, $cmd ) = @_;
#    my $plugin = $self->$orig($cmd);
#    $plugin->isa("MooseX::App::Cmd::Command")
#      and ensure_all_roles( $plugin, 'CLI::App::Perf::Index::Role::AutoHelp' );
#    return $plugin;
#};

__PACKAGE__->meta->make_immutable();

1;
