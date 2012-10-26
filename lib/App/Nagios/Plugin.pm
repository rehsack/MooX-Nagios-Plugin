package App::Nagios::Plugin;

use strictures;
use Moose;

extends qw(MooseX::App::Cmd);

# ABSTRACT: Application Performance Index CLI

__PACKAGE__->meta->make_immutable();

1;
