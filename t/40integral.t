use strict;
use warnings;
use Test::More tests => 13;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

# test simple integral and clone
use Math::SimpleHisto::XS qw(:all);
my $min = 11;
my $max = 102;
my $nbins = 39;
my $h = Math::SimpleHisto::XS->new(min => $min, max => $max, nbins => $nbins);
# make it so that for each 1 on the x axis, we get 1 in the integral!
$h->set_bin_content($_, $h->width/$nbins/$h->binsize) for 0..$nbins-1;

my $h2 = $h->clone;
for my $ht ($h, $h2) {
  is_approx($ht->integral($h->min, $h->max), $h->width, 'Check total integral', 1e-6);
  is_approx($ht->integral($h->min, $h->max, INTEGRAL_CONSTANT), $h->total*$h->binsize, 'Check total integral', 1e-6);
  is_approx($ht->integral($h->min+3.1, $h->max), $h->width-3.1, 'Check fractional start bin', 1e-6);
  is_approx($ht->integral($h->min+3.1, $h->max-12.), $h->width-3.1-12., 'Check fractional start and end bin', 1e-6);
  is_approx($ht->integral($h->min+3, $h->max-12., INTEGRAL_CONSTANT), $h->width-3-12, 'Check fractional start and end bin', 1e-6);
  is_approx($ht->integral(50.1, 50.2), 0.1, 'Check fractional start and end bin', 1e-6);
}

