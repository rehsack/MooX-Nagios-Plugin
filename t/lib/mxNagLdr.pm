package myNagLdr;

use Moo;
use MooX::Options;

sub fetch {}

with "MooX::Nagios::Plugin", "MooX::Nagios::Plugin::Fetch::Remote",
     "MooX::Nagios::Plugin::Approve::None", "MooX::Nagios::Plugin::Approve::Warn", "MooX::Nagios::Plugin::Approve::Crit";

1;
