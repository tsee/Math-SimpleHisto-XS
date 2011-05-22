use strict;
use warnings;
use Test::More tests => 226;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

my $hf = Math::SimpleHisto::XS->new(
  nbins => 200, min => 123.1, max => 255.9
);
my $hv = Math::SimpleHisto::XS->new(
  bins => [12000, 12001, 12001.1, 13000, 15000, 100000],
);

for my $h ($hf, $hv) {
  $h->fill($h->min + rand($h->width), rand(100)) for 1..1000;
}

foreach ([$hf, 'fixed bin size'], [$hv, 'variable bin size']) {
  my ($h, $name) = @$_;
  my $cum = $h->cumulative;

  # test simple properties
  isa_ok($cum, 'Math::SimpleHisto::XS');
  is($cum->nfills, $h->nfills, "nfills same ($name)");
  is_approx($cum->underflow, $h->underflow, "underflow same ($name)");
  is_approx($cum->overflow, $h->overflow, "overflow same ($name)");
  is_approx($cum->min, $h->min, "min same ($name)");
  is_approx($cum->max, $h->max, "max same ($name)");
  is_approx($cum->width, $h->width, "width same ($name)");
  is($cum->nbins, $h->nbins, "nbins same ($name)");
  is_approx($cum->binsize, $h->binsize, "binsize(0) same ($name)");
  is_approx($cum->binsize(3), $h->binsize(3), "binsize(3) same ($name)");

  my $sum = 0;
  foreach my $i (0..$h->nbins-1) {
    $sum += $h->bin_content($i);
    is_approx($cum->bin_content($i), $sum, "Cumulative bin content bin $i ($name)");
  }
}

