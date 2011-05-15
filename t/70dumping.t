use strict;
use warnings;
use Test::More tests => 3;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';

my $h = Math::SimpleHisto::XS->new(nbins => 23, min => 13.1, max => 99.2);

$h->fill(20.11, 12.4);
$h->fill(29.31, 123);
$h->fill(59., 59.);
$h->fill(32.91, 9,);
$h->fill(89.01, -2);
$h->set_overflow(12.);
$h->set_underflow(1.);

my $dump = $h->dump('simple');
ok(defined($dump), 'Simple dump is defined');
warn $dump;
my $clone = Math::SimpleHisto::XS->new_from_dump('simple', $dump);
isa_ok($clone, 'Math::SimpleHisto::XS');

