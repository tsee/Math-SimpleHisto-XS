use strict;
use warnings;
use Test::More tests => 2;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

my $bins = [];
my $x = 2.1;
push @$bins, sprintf("%.1f", $x+=$x/$_) for 1..11;
my $h = Math::SimpleHisto::XS->new(bins => $bins);
isa_ok($h, 'Math::SimpleHisto::XS');


