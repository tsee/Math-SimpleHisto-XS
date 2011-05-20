use strict;
use warnings;
use Test::More tests => 5 + 10*3;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

my $bins = [];
my $x = 2.1;
my $n = 10;
push @$bins, sprintf("%.1f", $x+=$x/$_) for 1..$n+1;
my $h = Math::SimpleHisto::XS->new(bins => $bins);
isa_ok($h, 'Math::SimpleHisto::XS');

is_deeply($h->bin_lower_boundaries(), [map 0+$_, @{$bins}[0..$n-1]], 'lower boundaries okay');
is_deeply($h->bin_upper_boundaries(), [map 0+$_, @{$bins}[1..$n]], 'upper boundaries okay');
is_deeply($h->bin_centers(), [map {0.5*($bins->[$_]+$bins->[$_+1])} 0..$n-1], 'bin centers okay');

foreach my $i (0..$n-1) {
  is_approx($h->bin_lower_boundary($i), $bins->[$i], "lower boundary bin $i");
  is_approx($h->bin_upper_boundary($i), $bins->[$i+1], "upper boundary bin $i");
  is_approx($h->bin_center($i), 0.5*($bins->[$i]+$bins->[$i+1]), "bin center $i");
}

