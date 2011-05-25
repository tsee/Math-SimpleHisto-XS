use strict;
use warnings;
use File::Spec;
my $dumpdir;
my %dump_data;
BEGIN {
  $dumpdir = File::Spec->catdir(qw(t data));
  $dumpdir = 'data' if not -d $dumpdir;
  die "Cannot find data directory" if not -d $dumpdir;

  opendir my $dh, $dumpdir
    or die "Cannot open $dumpdir: $!";
  my @vers_files = map {/^dumps\.(.+)\.txt$/?[$1, $_]:()} readdir($dh);

  my $tests_per_dump = 12;
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
    }
    close $fh;
  }
}

use Test::More;
BEGIN { use_ok('Math::SimpleHisto::XS') };

use lib 't/lib', 'lib';
use Test_Functions;

my %types_seen;
foreach my $version (sort {$b <=> $a} keys %dump_data) {
  diag("Testing dumps for version $version");
  my $ref_histo;
  foreach my $type (sort keys %{$dump_data{$version}}) {
    if (not exists $types_seen{lc $type}) {
      $types_seen{lc $type} = 0;
      if (lc($type) eq 'yaml') {
        eval "require YAML::Tiny; 1;" or diag("No YAML::Tiny, skipping this dump"), next;
      }
      elsif (lc($type) eq 'json') {
        $Math::SimpleHisto::XS::JSON or diag("No JSON support, skipping this dump"), next;
      }
      $types_seen{lc $type} = 1;
    }
    elsif (not $types_seen{lc $type}) {
      next;
    }

    my $histo = Math::SimpleHisto::XS->new_from_dump(
      $type, $dump_data{$version}{$type}
    );
    isa_ok($histo, 'Math::SimpleHisto::XS');
    $ref_histo = $histo if not defined $ref_histo;
    histo_eq($histo, $ref_histo, "Histo '$type' is equal to reference, $version");
  }
}

done_testing();
