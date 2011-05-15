use strict;
use warnings;
use Test::More tests => 92;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

my $h = Math::SimpleHisto::XS->new(nbins => 10, min => 0, max => 1);
isa_ok($h, 'Math::SimpleHisto::XS');

$h->fill(0.11, 12.4);
pass("Alive");

my $data = $h->all_bin_contents;
ok(ref($data) && ref($data) eq 'ARRAY', "got ary ref");
is(scalar(@$data), 10, "10 bins");
is($h->nfills, 1, "1 fill");
is_approx($h->total, 12.4, "total is right");
SCOPE: {
  my $exp = [0,12.4,(0)x8];
  for (0..9) {
    is_approx($data->[$_], $exp->[$_], "Bin $_ is right");
    is_approx($h->bin_content($_), $exp->[$_], "Bin $_ is right (extra call)");
  }
}

$h->fill(-2.);
$h->fill(0.5);
$h->fill(0.5, 13.);
$h->fill([0.5], [13.]);
$h->fill([0.5, 2.], [13., 1.]);
pass("alive");

my $hclone = $h->new_alike();
is($hclone->nfills, 0, "new_alike returns fresh object");
is($hclone->total, 0, "new_alike returns fresh object");
is_approx($hclone->overflow, 0, "new_alike returns fresh object");
is_approx($hclone->underflow, 0, "new_alike returns fresh object");

SCOPE: {
  my $exp = [map $_/10, 0..9];
  my $c = $h->bin_centers();
  my $up = $h->bin_upper_boundaries();
  my $low = $h->bin_lower_boundaries();
  for (0..9) {
    is_approx($low->[$_], $exp->[$_], "Bin $_ is lower boundary is right");
    is_approx($h->bin_lower_boundary($_), $exp->[$_], "Bin $_ is lower boundary is right (extra call)");
    is_approx($c->[$_], $exp->[$_]+0.05, "Bin $_ center is right");
    is_approx($h->bin_center($_), $exp->[$_]+0.05, "Bin $_ center is right (extra call)");
    is_approx($up->[$_], $exp->[$_]+0.1, "Bin $_ upper boundary is right");
    is_approx($h->bin_upper_boundary($_), $exp->[$_]+0.1, "Bin $_ upper boundary is right (extra call)");
  }
}


# memory leaks
#while (1) {do {my $x = $h->all_bin_contents()}}
#while (1) {  do {my $h = Math::SimpleHisto::XS->new(nbins => 100, min => 0, max => 1);};}
#while (1) {  do {$h->fill([0.5], [1.]);};}

