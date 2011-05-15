package
  Test_Functions;
use strict;
use warnings;
require Test::More;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_approx);

sub is_approx {
  my $delta = $_[3] || 1e-9;
  Test::More::ok($_[0] > $_[1]-$delta && $_[0] < $_[1]+$delta, (@_ > 2 ? ($_[2]) : ()))
    or Test::More::diag("Got $_[0], expected $_[1]");
}

1;

