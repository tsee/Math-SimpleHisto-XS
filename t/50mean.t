use strict;
use warnings;
use Test::More tests => 5;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

# mean
my $h = Math::SimpleHisto::XS->new(min => 0, max => 10, nbins => 100000);
$h->fill(1);
$h->fill(2);
$h->fill(3);
is_approx($h->mean(), 2, "mean test 1", 1e-4);

{
  my $hclone = $h->clone;
  $hclone->fill(2, 10);
  is_approx($hclone->mean(), 2, "mean test 2", 1e-4);
}

$h->fill(5,2);
is_approx($h->mean(), 3.2, "mean test 3", 1e-4);

$h->fill(8,10000000);
is_approx($h->mean(), 8, "mean test 4", 1e-4);

