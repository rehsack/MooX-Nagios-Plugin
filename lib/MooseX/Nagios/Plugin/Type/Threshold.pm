package MooseX::Nagios::Plugin::Type::Threshold;

use strictures;
use Moose::Role;

# ABSTRACT: MooseX::Nagios role loading the L<MooseX::Types::Threshold> type traits

use MooseX::Types::Threshold;

{
    package    # do not confuse PAUSE
      MooseX::Nagios::Meta::ThresholdCmp::Attribute::Trait;

    use Moose::Role;
    use Moose::Util::TypeConstraints;

    has 'compare_modificator' => (
                                   is      => 'rw',
                                   isa     => 'Int',
                                   default => 1,
                                 );

    no Moose::Util::TypeConstraints;
}

no Moose::Role;

{
    # register this as a metaclass alias ...
    package    # stop confusing PAUSE
      Moose::Meta::Attribute::Custom::Trait::ThresholdCmp;
    sub register_implementation { 'MooseX::Nagios::Meta::ThresholdCmp::Attribute::Trait' }
}

1;
