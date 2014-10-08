package Types::Tiny::Thresholds;

use 5.014;
use strictures;

our $VERSION = "0.003";

=head1 NAME

Types::Tiny::Thresholds - Thresholds by Types::Tiny

=cut

{
    package    # hide from cpan
      Type::Threshold::Relative;

    use overload
      '<'   => \&my_lt,
      '<='  => \&my_le,
      '=='  => \&my_eq,
      '!='  => \&my_ne,
      '>'   => \&my_gt,
      '>='  => \&my_ge,
      '<=>' => \&compare,
      '0+'  => sub { $_[0]->{percent} };
    use Carp qw/croak/;

    sub new
    {
        my ( $class, @args ) = @_;
        @args = map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; $_ } @args;
        scalar(@args) >= 1 or croak "Type::Threshold::Relative->new('rel[%]')";
        scalar(@args) <= 1 or croak "Type::Threshold::Relative->new('rel[%]')";

        my $self = bless( {}, $class );

        for my $arg (@args)
        {
            if ( $arg =~ m/^(\d+)%?$/ )
            {
                $self->{percent} = $1;
            }
            else
            {
                croak "Neither absolute nor relative value: '$arg'";
            }
        }

        defined( $self->{percent} )
          or croak("Type::Threshold::Relative->new('rel[%]')");

        return $self;
    }

    sub new_with_params
    {
        my ( $class, %params ) = @_;
        my $self = bless( {}, $class );

        $self->{percent} = $params{value} || 0;

        return $self;
    }

    sub compare
    {
        my ( $self, $other ) = @_;
        my $result;

        ref($other) or $other = Type::Threshold::Relative->new($other);

        if ( defined( $self->{percent} ) and defined( $other->{percent} ) )
        {
            $result = $self->{percent} <=> $other->{percent};
        }

        defined($result)
          or croak( "\$self("
              . join( ", ", grep { defined $self->{$_} } qw(percent) )
              . ") and \$other("
              . join( ", ", grep { defined $self->{$_} } qw(percent) )
              . ") have no common comparable attributes" );

        return $result;
    }

    sub my_lt { return $_[0]->compare( $_[1] ) < 0; }
    sub my_le { return $_[0]->compare( $_[1] ) <= 0; }
    sub my_eq { return $_[0]->compare( $_[1] ) == 0; }
    sub my_ne { return $_[0]->compare( $_[1] ) != 0; }
    sub my_gt { return $_[0]->compare( $_[1] ) > 0; }
    sub my_ge { return $_[0]->compare( $_[1] ) >= 0; }

    1;
}

{
    package    # hide from cpan
      Type::Threshold::Size;

    use overload
      '<'   => \&my_lt,
      '<='  => \&my_le,
      '=='  => \&my_eq,
      '!='  => \&my_ne,
      '>'   => \&my_gt,
      '>='  => \&my_ge,
      '<=>' => \&compare;
    use Carp qw/croak/;

    my %unit_sizes = (
        'b' => 1,
        'k' => 1024,
        'm' => 1024 * 1024,
        'g' => 1024 * 1024 * 1024,
        't' => 1024 * 1024 * 1024 * 1024,
        'p' => 1024 * 1024 * 1024 * 1024 * 1024,
    );
    my $rx_str = join( '|', map { $_, uc $_ } keys %unit_sizes );

    sub new
    {
        my ( $class, @args ) = @_;
        scalar(@args) == 1 and !ref( $args[0] ) and $args[0] and @args = split( ",", $args[0] );
        @args = map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; $_ } @args;
        scalar(@args) >= 1 or croak "Type::Threshold::Size->new('size[unit],rel[%]')";
        scalar(@args) <= 2 or croak "Type::Threshold::Size->new('size[unit],rel[%]')";

        my $self = bless( {}, $class );

        for my $arg (@args)
        {
            if ( $arg =~ m/^(\d+)($rx_str)?$/ )
            {
                my $size = $1;
                my $unit = $2;
                $unit and $unit = $unit_sizes{ lc $unit };
                $unit ||= 1;

                $self->{size} = $size;
                $self->{unit} = $unit;
            }
            elsif ( $arg =~ m/^(\d+)%?/ )
            {
                $self->{percent} = $1;
            }
            else
            {
                croak "Neither absolute nor relative value: '$arg'";
            }
        }

        defined( $self->{size} )
          or defined( $self->{percent} )
          or croak("Type::Threshold::Size->new('size[unit],rel[%]')");

        $self->{compare_modificator} = 1;

        return $self;
    }

    sub new_with_params
    {
        my ( $class, %params ) = @_;
        my $self = bless( {}, $class );

        $self->{size} = $params{value} || 0;
        defined( $params{unit} )                   or $params{unit} = "b";
        defined( $unit_sizes{ lc $params{unit} } ) or $params{unit} = "b";
        $self->{unit_name}           = $params{unit};
        $self->{unit}                = $unit_sizes{ lc $self->{unit_name} };
        $self->{fmt}                 = $params{fmt} || "%d" . $self->{unit_name};
        $self->{compare_modificator} = $params{compare_modificator} // 1;

        return $self;
    }

    sub compare
    {
        my ( $self, $other ) = @_;
        my $result;

        ref($other) or $other = Type::Threshold::Size->new($other);

        if ( defined( $self->{percent} ) and defined( $other->{percent} ) )
        {
            $result = $self->{percent} <=> $other->{percent};
        }

        if ( defined( $self->{size} ) and defined( $other->{size} ) )
        {
            $result = ( $self->{size} * $self->{unit} ) <=> ( $other->{size} * $other->{unit} );
        }

        defined($result)
          or croak( "\$self("
              . join( ", ", grep { defined $self->{$_} } qw(size unit percent) )
              . ") and \$other("
              . join( ", ", grep { defined $self->{$_} } qw(size unit percent) )
              . ") have no common comparable attributes" );

        return $self->{compare_modificator} * $result;
    }

    sub my_lt { return $_[0]->compare( $_[1] ) < 0; }
    sub my_le { return $_[0]->compare( $_[1] ) <= 0; }
    sub my_eq { return $_[0]->compare( $_[1] ) == 0; }
    sub my_ne { return $_[0]->compare( $_[1] ) != 0; }
    sub my_gt { return $_[0]->compare( $_[1] ) > 0; }
    sub my_ge { return $_[0]->compare( $_[1] ) >= 0; }

    1;
}

{
    package    # hide from cpan
      Type::Threshold::Time;

    use overload
      '<'   => \&my_lt,
      '<='  => \&my_le,
      '=='  => \&my_eq,
      '!='  => \&my_ne,
      '>'   => \&my_gt,
      '>='  => \&my_ge,
      '<=>' => \&compare,
      '""'  => sub { sprintf( $_[0]->{fmt}, $_[0]->{duration} ) },
      '0+' => sub { $_[0]->{duration} * $_[0]->{unit} };
    use Carp qw/croak/;

    my %unit_sizes = (
        'ns'  => 1,
        'µs' => 1000,
        'ms'  => 1000 * 1000,
        's'   => 1000 * 1000 * 1000,
        'm'   => 60 * 1000 * 1000 * 1000,
        'h'   => 60 * 60 * 1000 * 1000 * 1000,
        'd'   => 24 * 60 * 60 * 1000 * 1000 * 1000,
        'w'   => 7 * 24 * 60 * 60 * 1000 * 1000 * 1000,
    );
    my $rx_str = join( '|', map { $_, uc $_ } keys %unit_sizes );

    sub new
    {
        my ( $class, @args ) = @_;
        scalar(@args) == 1 and !ref( $args[0] ) and $args[0] and @args = split( ",", $args[0] );
        @args = map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; $_ } @args;
        scalar(@args) >= 1 or croak "Type::Threshold::Time->new('time[unit]')";
        scalar(@args) <= 1 or croak "Type::Threshold::Time->new('time[unit]')";

        for my $arg (@args)
        {
            $arg =~ m/^(\d+)($rx_str)?$/ and return $class->new_with_params(
                value               => $1,
                unit                => $2,
                compare_modificator => 1,
            );

            croak "Invalid time value: '$arg'";
        }

        croak("Type::Threshold::Time->new('time[unit]')");
    }

    sub new_with_params
    {
        my ( $class, %params ) = @_;
        my $self = bless( {}, $class );

        $self->{duration} = $params{value} || 0;
        defined( $params{unit} )                   or $params{unit} = "s";
        defined( $unit_sizes{ lc $params{unit} } ) or $params{unit} = "s";
        $self->{unit_name}           = $params{unit};
        $self->{unit}                = $unit_sizes{ lc $self->{unit_name} };
        $self->{fmt}                 = $params{fmt} || "%d" . $self->{unit_name};
        $self->{compare_modificator} = $params{compare_modificator} // 1;

        return $self;
    }

    sub update_unit
    {
        my ( $self, %params ) = @_;
        my $value = $self->${ \overload::Method( $self, '0+' ) };    # $this->operator 0+ ()
        defined( $params{unit} )                   or $params{unit} = "s";
        defined( $unit_sizes{ lc $params{unit} } ) or $params{unit} = "s";
        $self->{unit_name} = $params{unit};
        $self->{unit}      = $unit_sizes{ lc $self->{unit_name} };
        $self->{fmt}       = $params{fmt} || "%d" . $self->{unit_name};
        $self->{duration}  = $value / $self->{unit};

        return $self;
    }

    sub compare
    {
        my ( $self, $other ) = @_;
        my $result;

        ref($other) or $other = Type::Threshold::Time->new($other);

        if ( defined( $self->{duration} ) and defined( $other->{duration} ) )
        {
            $result =
              ( $self->{duration} * $self->{unit} ) <=> ( $other->{duration} * $other->{unit} );
        }

        defined($result)
          or croak( "\$self("
              . join( ", ", grep { defined $self->{$_} } qw(duration unit) )
              . ") and \$other("
              . join( ", ", grep { defined $self->{$_} } qw(duration unit) )
              . ") have no common comparable attributes" );

        return $self->{compare_modificator} * $result;
    }

    sub my_lt { return $_[0]->compare( $_[1] ) < 0; }
    sub my_le { return $_[0]->compare( $_[1] ) <= 0; }
    sub my_eq { return $_[0]->compare( $_[1] ) == 0; }
    sub my_ne { return $_[0]->compare( $_[1] ) != 0; }
    sub my_gt { return $_[0]->compare( $_[1] ) > 0; }
    sub my_ge { return $_[0]->compare( $_[1] ) >= 0; }

    1;
}

#{
#    package    # hide from cpan
#	Type::Threshold::Range;
#
#    use overload
#	'<'   => \&my_lt,
#	'<='  => \&my_le,
#	'=='  => \&my_eq,
#	'!='  => \&my_ne,
#	'>'   => \&my_gt,
#	'>='  => \&my_ge,
#	'<=>' => \&compare;
#    use Carp qw/croak/;
#
#    sub new
#    {
#	my ( $class, @args ) = @_;
#	scalar(@args) == 1 and !ref( $args[0] ) and $args[0] and @args = split( ":", $args[0] );
#	scalar(@args) == 1 and 'ARRAY' eq ref( $args[0] ) and @args = @{ $args[0] };
#	@args = map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; $_ } @args;
#	scalar(@args) >= 1 or croak "Type::Threshold::Range->new('[min]:[max]')";
#	scalar(@args) <= 2 or croak "Type::Threshold::Range->new('[min]:[max]')";
#
#	my $self = bless( {}, $class );
#
#	for my $arg (@args)
#	{
#	    if ( $arg =~ m/^(\d+)$/ )
#	    {
#		$arg = $1;
#	    }
#	    elsif ( !$arg )
#	    {
#		$arg = undef;
#	    }
#	    else
#	    {
#		croak "Not a number: '$arg'";
#	    }
#	}
#
#	$self->{min} = $args[0];
#	$self->{max} = $args[1];
#
#	defined( $self->{min} )
#	    or defined( $self->{max} )
#	    or croak("Neither min nor max for range in Type::Threshold::Range->new('[min]:[max]')");
#
#	defined $self->{min}
#	and defined $self->{max}
#	and $self->{min} > $self->{max}
#	and $self->{negated} = 1;
#
#	return $self;
#    }
#}

use Type::Library
  -base,
  -declare => qw(TimeThreshold TimeThresholdHash SizeThresholdHash SizeThreshold RelativeThreshold);
use Type::Utils;
use Types::Standard -types;

class_type TimeThreshold,     { class => 'Type::Threshold::Time' };
class_type SizeThreshold,     { class => 'Type::Threshold::Size' };
class_type RelativeThreshold, { class => 'Type::Threshold::Relative' };

declare TimeThresholdHash,
  as Dict [
    value               => Int,
    unit                => Optional [Str],
    fmt                 => Optional [Str],
    compare_modificator => Optional [Int],
  ];

declare SizeThresholdHash,
  as Dict [
    value               => Int,
    unit                => Optional [Str],
    fmt                 => Optional [Str],
    compare_modificator => Optional [Int],
  ];

coerce TimeThreshold,
  from Int, via { "Type::Threshold::Time"->new_with_params( value => $_ ) },
  from Str, via { "Type::Threshold::Time"->new($_) },
  from TimeThresholdHash, via { "Type::Threshold::Time"->new_with_params(%$_) };

coerce SizeThreshold,
  from Int, via { "Type::Threshold::Size"->new_with_params( value => $_ ) },
  from Str, via { "Type::Threshold::Size"->new($_) },
  from SizeThresholdHash, via { "Type::Threshold::Size"->new_with_params(%$_) };

1;
