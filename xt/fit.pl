use strict;
use warnings;

# Note: This isn't statistically correct if you're going to use
#       weights when filling the histogram.

use Algorithm::CurveFit;
use Math::SimpleHisto::XS;
use Math::Random::OO::Normal;
use Math::SymbolicX::Statistics::Distributions ':functions';
use Data::Dumper;
use List::Util qw(max);

my $rnd = Math::Random::OO::Normal->new(30, 10);
my $h = Math::SimpleHisto::XS->new(
  nbins => 100, min => 0., max => 100.
);

$h->fill($rnd->next) for 1..100000;
$h->normalize;

my @params = (
  [mu    => 28.1, 0.001],
  [sigma => 1.8, 0.01],
);
my $formula = ( normal_distribution('mu', 'sigma'));
my $residual = Algorithm::CurveFit->curve_fit(
  formula => $formula,
  xdata   => $h->bin_centers,
  ydata   => $h->all_bin_contents,
  params  => \@params,
);

warn $residual;
warn Dumper \@params;

