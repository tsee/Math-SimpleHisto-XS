use strict;
use warnings;
use File::Spec;
my $dumpdir;
my %dump_data;
my $tests;
BEGIN {
  $dumpdir = File::Spec->catdir(qw(t data));
  $dumpdir = 'data' if not -d $dumpdir;
  die "Cannot find data directory" if not -d $dumpdir;

  opendir my $dh, $dumpdir
    or die "Cannot open $dumpdir: $!";
  my @vers_files = map {/^dumps\.(.+)\.txt$/?[$1, $_]:()} readdir($dh);

  my $tests_per_dump = 12;
  $tests = 1;
  foreach my $version_file (@vers_files) {
    my ($version, $file) = @$version_file;
    $file = File::Spec->catfile($dumpdir, $file);
    open my $fh, "<", $file or die "Cannot open file for reading: $!";
    binmode $fh;
    local $/ = ""; # paragraph mode
    my $dumps = $dump_data{$version} = {};
    while (<$fh>) {
      my ($type, $data) = split /:/, $_, 2;
      chomp $data;
      $data .= "\n" if $type =~ /^yaml$/i;
      #warn "$type:'$data'";
      $dumps->{$type} = $data;
      $tests += $tests_per_dump;
    }
    close $fh;
  }
}

use Test::More tests => $tests;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

foreach my $version (sort {$b <=> $a} keys %dump_data) {
  diag("Testing dumps for version $version");
  my $ref_histo;
  foreach my $type (sort keys %{$dump_data{$version}}) {
    my $histo = Math::SimpleHisto::XS->new_from_dump(
      $type, $dump_data{$version}{$type}
    );
    isa_ok($histo, 'Math::SimpleHisto::XS');
    $ref_histo = $histo if not defined $ref_histo;
    histo_eq($histo, $ref_histo, "Histo '$type' is equal to reference, $version");
  }
}

