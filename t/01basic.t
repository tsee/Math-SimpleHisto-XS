use strict;
use warnings;
use Test::More tests => 87;
BEGIN { use_ok('Math::SimpleHisto::XS') };

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


#while (1) {do {my $x = $h->all_bin_contents()}}

#while (1) {  do {my $h = Math::SimpleHisto::XS->new(nbins => 100, min => 0, max => 1);};}
#while (1) {  do {$h->fill([0.5], [1.]);};}

#$h->fill($_*1e-4) for 1..1e4;
#ok($h->mean() > 0.49 && $h->mean() < 0.51);

#$h = Histo->new(xbins => 100, xmin => 0, xmax => 1);

#use Math::Random::OO::Normal;
#my $gauss = Math::Random::OO::Normal->new(0.5,0.1);
#$h->fill($gauss->next) for 1..1e5;

#warn $h->mean;
#warn $h->mean_variance;
#warn $h->uncertainty_on_mean;
#warn $h->std_dev;

sub is_approx {
  ok($_[0] > $_[1]-1e-9 && $_[0] < $_[1]+1e-9, (@_ > 2 ? ($_[2]) : ()))
    or diag("Got $_[0], expected $_[1]");
}
