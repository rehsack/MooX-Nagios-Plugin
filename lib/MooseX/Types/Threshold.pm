package MooseX::Types::Threshold;

use strictures;

# ABSTRACT: defines some reasonable threshold types for nagios checks

use MooseX::Types '-declare' =>
  [qw(Threshold TimeThreshold SizeThreshold RangeThreshold RelativeThreshold)];

use MooseX::Types::Moose qw(Int Str ArrayRef);

class_type('Threshold::Time');
class_type('Threshold::Size');
class_type('Threshold::Range');
class_type('Threshold::Relative');

subtype SizeThreshold,     as 'Threshold::Size';
subtype RangeThreshold,    as 'Threshold::Range';
subtype RelativeThreshold, as 'Threshold::Relative';
subtype TimeThreshold,     as 'Threshold::Time';

for my $type ( 'Threshold::Size', SizeThreshold )
{
    coerce $type,
      from Int,      via { Threshold::Size->new($_) },
      from Str,      via { Threshold::Size->new($_) },
      from ArrayRef, via { Threshold::Size->new(@$_) };
}

for my $type ( 'Threshold::Time', TimeThreshold )
{
    coerce $type,
      from Int,      via { Threshold::Time->new($_) },
      from Str,      via { Threshold::Time->new($_) },
      from ArrayRef, via { Threshold::Time->new(@$_) };
}

for my $type ( 'Threshold::Range', RangeThreshold )
{
    coerce $type,
      from Int,      via { Threshold::Range->new($_) },
      from Str,      via { Threshold::Range->new($_) },
      from ArrayRef, via { Threshold::Range->new(@$_) };
}

for my $type ( 'Threshold::Relative', RelativeThreshold )
{
    coerce $type,
      from Int,      via { Threshold::Relative->new($_) },
      from Str,      via { Threshold::Relative->new($_) },
      from ArrayRef, via { Threshold::Relative->new(@$_) };
}

# optionally add Getopt option type
eval { require MooseX::Getopt; };
if ( !$@ )
{
    MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $_, '=s', )
      for (
            'Threshold::Time',     'Threshold::Size', 'Threshold::Range',
            'Threshold::Relative', TimeThreshold,     SizeThreshold,
            RangeThreshold,        RelativeThreshold,
          );
}

{
    package    # hide from cpan
      Threshold::Relative;

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
        scalar(@args) >= 1 or croak "Threshold::Size->new('rel[%]')";
        scalar(@args) <= 1 or croak "Threshold::Size->new('rel[%]')";

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
          or croak("Threshold::Size->new('rel[%]')");

        return $self;
    }

    sub compare
    {
        my ( $self, $other ) = @_;
        my $result;

        ref($other) or $other = Threshold::Relative->new($other);

        if ( defined( $self->{percent} ) and defined( $other->{percent} ) )
        {
            $result = $self->{percent} <=> $other->{percent};
        }

        defined($result)
          or croak(   "\$self("
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
      Threshold::Size;

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
        scalar(@args) >= 1 or croak "Threshold::Size->new('size[unit],rel[%]')";
        scalar(@args) <= 2 or croak "Threshold::Size->new('size[unit],rel[%]')";

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
          or croak("Threshold::Size->new('size[unit],rel[%]')");

        return $self;
    }

    sub compare
    {
        my ( $self, $other ) = @_;
        my $result;

        ref($other) or $other = Threshold::Size->new($other);

        if ( defined( $self->{percent} ) and defined( $other->{percent} ) )
        {
            $result = $self->{percent} <=> $other->{percent};
        }

        if ( defined( $self->{size} ) and defined( $other->{size} ) )
        {
            $result = ( $self->{size} * $self->{unit} ) <=> ( $other->{size} * $other->{unit} );
        }

        defined($result)
          or croak(   "\$self("
                    . join( ", ", grep { defined $self->{$_} } qw(size unit percent) )
                    . ") and \$other("
                    . join( ", ", grep { defined $self->{$_} } qw(size unit percent) )
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
      Threshold::Time;

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
        scalar(@args) >= 1 or croak "Threshold::Time->new('time[unit]')";
        scalar(@args) <= 1 or croak "Threshold::Time->new('time[unit]')";

        for my $arg (@args)
        {
            $arg =~ m/^(\d+)($rx_str)?$/ and return
              $class->new_with_params( value => $1,
                                       unit  => $2 );

            croak "Invalid time value: '$arg'";
        }

        croak("Threshold::Time->new('time[unit]')");
    }

    sub new_with_params
    {
        my ( $class, %params ) = @_;
        my $self = bless( {}, $class );

        $self->{duration} = $params{value} || 0;
        defined( $params{unit} )                   or $params{unit} = "s";
        defined( $unit_sizes{ lc $params{unit} } ) or $params{unit} = "s";
        $self->{unit_name} = $params{unit};
        $self->{unit}      = $unit_sizes{ lc $self->{unit_name} };
        $self->{fmt}       = $params{fmt} || "%d" . $self->{unit_name};

        return $self;
    }

    sub update_unit
    {
        my ( $self, %params ) = @_;
        my $value = int($self);
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

        ref($other) or $other = Threshold::Time->new($other);

        if ( defined( $self->{duration} ) and defined( $other->{duration} ) )
        {
            $result =
              ( $self->{duration} * $self->{unit} ) <=> ( $other->{duration} * $other->{unit} );
        }

        defined($result)
          or croak(   "\$self("
                    . join( ", ", grep { defined $self->{$_} } qw(duration unit) )
                    . ") and \$other("
                    . join( ", ", grep { defined $self->{$_} } qw(duration unit) )
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
      Threshold::Range;

    use overload
      '<'   => \&my_lt,
      '<='  => \&my_le,
      '=='  => \&my_eq,
      '!='  => \&my_ne,
      '>'   => \&my_gt,
      '>='  => \&my_ge,
      '<=>' => \&compare;
    use Carp qw/croak/;

    sub new
    {
        my ( $class, @args ) = @_;
        scalar(@args) == 1 and !ref( $args[0] ) and $args[0] and @args = split( ":", $args[0] );
        scalar(@args) == 1 and 'ARRAY' eq ref( $args[0] ) and @args = @{ $args[0] };
        @args = map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; $_ } @args;
        scalar(@args) >= 1 or croak "Threshold::Range->new('[min]:[max]')";
        scalar(@args) <= 2 or croak "Threshold::Range->new('[min]:[max]')";

        my $self = bless( {}, $class );

        for my $arg (@args)
        {
            if ( $arg =~ m/^(\d+)$/ )
            {
                $arg = $1;
            }
            elsif ( !$arg )
            {
                $arg = undef;
            }
            else
            {
                croak "Not a number: '$arg'";
            }
        }

        $self->{min} = $args[0];
        $self->{max} = $args[1];

        defined( $self->{min} )
          or defined( $self->{max} )
          or croak("Neither min nor max for range in Threshold::Range->new('[min]:[max]')");

              defined $self->{min}
          and defined $self->{max}
          and $self->{min} > $self->{max}
          and $self->{negated} = 1;

        return $self;
    }
}

1;
