package
  Test_Functions;
use strict;
use warnings;
require Test::More;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_approx histo_eq);

sub is_approx {
  my $delta = $_[3] || 1e-9;
  Test::More::ok($_[0] > $_[1]-$delta && $_[0] < $_[1]+$delta, (@_ > 2 ? ($_[2]) : ()))
    or Test::More::diag("Got $_[0], expected $_[1]");
}


sub histo_eq {
  my ($ref, $test, $name) = @_;
  $name = "hist. compare" if not defined $name;

  Test::More::is($test->min, $ref->min, "min is the same ($name)");
  Test::More::is($test->max, $ref->max, "max is the same ($name)");
  Test::More::is($test->nbins, $ref->nbins, "nbins is the same ($name)");
  Test::More::is($test->nfills, $ref->nfills, "nbins is the same ($name)");
  is_approx($test->overflow, $ref->overflow, "overflow is the same ($name)");
  is_approx($test->underflow, $ref->underflow, "underflow is the same ($name)");
  is_approx($test->total, $ref->total, "total is the same ($name)");
  is_approx($test->width, $ref->width, "width is the same ($name)");
  is_approx($test->binsize, $ref->binsize, "binsize is the same ($name)");

  Test::More::is_deeply($test->all_bin_contents, $ref->all_bin_contents, "data is the same ($name)");
  Test::More::is_deeply($test->bin_centers, $ref->bin_centers, "bin centers are the same ($name)");
}


1;

