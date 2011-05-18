use strict;
use warnings;
use Test::More tests => 59;
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
SCOPE: {
  my $dump = $h->dump('simple');
  ok(defined($dump), 'Simple dump is defined');

  my $clone = Math::SimpleHisto::XS->new_from_dump('simple', $dump);
  isa_ok($clone, 'Math::SimpleHisto::XS');
  histo_eq($h, $clone, "Simple histo dump");
}

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
  if (not eval "require JSON; 1;") {
    skip 'Could not load JSON', 12;
  }
  my $dump = $h->dump('json');
  ok(defined($dump), 'JSON dump is defined');

  my $clone = Math::SimpleHisto::XS->new_from_dump('json', $dump);
  isa_ok($clone, 'Math::SimpleHisto::XS');
  histo_eq($h, $clone, "JSON histo dump");
}

# YAML
SKIP: {
  if (not eval "require YAML::Tiny; 1;") {
    skip 'Could not load YAML::Tiny', 12;
  }
  my $dump = $h->dump('yaml');
  ok(defined($dump), 'YAML dump is defined');

  my $clone = Math::SimpleHisto::XS->new_from_dump('yaml', $dump);
  isa_ok($clone, 'Math::SimpleHisto::XS');
  histo_eq($h, $clone, "YAML histo dump");
}

