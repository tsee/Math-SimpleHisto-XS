use strict;
use warnings;
use Test::More tests => 71;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

my $h = Math::SimpleHisto::XS->new(nbins => 23, min => 13.1, max => 99.2);

$h->fill(20.11, 12.4);
$h->fill(29.31, 123);
$h->fill(59., 59.);
$h->fill(32.91, 9,);
$h->fill(89.01, -2);
$h->set_overflow(12.);
$h->set_underflow(1.);

# simple dump
test_dump_undump($h, 'simple');

# native_pack
test_dump_undump($h, 'native_pack');

# Storable
SKIP: {
  if (not eval "require Storable; 1;") {
    skip 'Could not load Storable', 22;
  }
  my $cloned = Storable::thaw(Storable::nfreeze($h));
  isa_ok($cloned, 'Math::SimpleHisto::XS');
  histo_eq($h, $cloned, "Storable thaw(nfreeze())");
  $cloned = Storable::dclone($h);
  isa_ok($cloned, 'Math::SimpleHisto::XS');
  histo_eq($h, $cloned, "Storable dclone");
}

# JSON
SKIP: {
  if (not defined $Math::SimpleHisto::XS::JSON) {
    skip 'Could not load JSON support module', 12;
  }
  diag("Using $Math::SimpleHisto::XS::JSON_Implementation for testing JSON support");
  test_dump_undump($h, 'json');
}

# YAML
SKIP: {
  if (not eval "require YAML::Tiny; 1;") {
    skip 'Could not load YAML::Tiny', 12;
  }
  test_dump_undump($h, 'yaml');
}

sub test_dump_undump {
  my $histo = shift;
  my $type = shift;

  my $dump = $histo->dump($type);
  ok(defined($dump), "'$type' dump is defined");

  my $clone = Math::SimpleHisto::XS->new_from_dump($type, $dump);
  isa_ok($clone, 'Math::SimpleHisto::XS');
  histo_eq($histo, $clone, "'$type' histo dump is same as original");
}

