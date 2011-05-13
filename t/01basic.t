use strict;
use warnings;
use Test::More tests => 121;
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


# test simple integral and clone
SCOPE: {
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

}

# memory leaks
#while (1) {do {my $x = $h->all_bin_contents()}}
#while (1) {  do {my $h = Math::SimpleHisto::XS->new(nbins => 100, min => 0, max => 1);};}
#while (1) {  do {$h->fill([0.5], [1.]);};}


# mean
SCOPE: {
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
}

# normalize
SCOPE: {
  my $h = Math::SimpleHisto::XS->new(min => 0, max => 10, nbins => 10);
  $h->fill(1);
  $h->fill(2, 2);
  $h->fill(3, 3);
  $h->normalize;
  is_approx($h->bin_content(1), 1/6, 'normalization bin 1', 1e-6);
  is_approx($h->bin_content(2), 2/6, 'normalization bin 2', 1e-6);
  is_approx($h->bin_content(3), 3/6, 'normalization bin 3', 1e-6);
  is_approx($h->bin_content(4), 0, 'normalization bin 4', 1e-6);
  is_approx($h->total, 1., 'normalization total', 1e-6);
  is_approx($h->integral($h->min, $h->max), 1, 'normalization integral', 1e-6);
  my $clone = $h->clone;
  {
    $clone->fill(3, 3);
    is_approx($clone->bin_content(3), 3+3/6, 'normalization, fill bin 3', 1e-6);
  }
  $h->normalize(2.5);
  is_approx($h->total, 2.5, 'renormalization total', 1e-6);
  is_approx($h->integral($h->min, $h->max), 2.5, 'renormalization integral', 1e-6);
  is_approx($h->bin_content(1), 2.5*1/6, 'renormalization bin 1', 1e-6);
  is_approx($h->bin_content(2), 2.5*2/6, 'renormalization bin 2', 1e-6);
  is_approx($h->bin_content(3), 2.5*3/6, 'renormalization bin 3', 1e-6);
  is_approx($h->bin_content(4), 0, 'renormalization bin 4', 1e-6);

}

sub is_approx {
  my $delta = $_[3] || 1e-9;
  ok($_[0] > $_[1]-$delta && $_[0] < $_[1]+$delta, (@_ > 2 ? ($_[2]) : ()))
    or diag("Got $_[0], expected $_[1]");
}
