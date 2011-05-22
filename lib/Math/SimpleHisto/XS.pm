package Math::SimpleHisto::XS;
use 5.008001;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '1.01'; # Committed to floating point version numbers!

require XSLoader;
XSLoader::load('Math::SimpleHisto::XS', $VERSION);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
  INTEGRAL_CONSTANT
);
  #INTEGRAL_POL1

our %EXPORT_TAGS = (
  'all' => \@EXPORT_OK,
);

our @JSON_Modules = qw(JSON::XS JSON::PP JSON);
our $JSON_Implementation;
our $JSON;

foreach my $json_module (@JSON_Modules) {
  if (eval "require $json_module; 1;") {
    $JSON = $json_module->new;
    $JSON->indent(0) if $JSON->can('indent');
    $JSON->space_before(0) if $JSON->can('space_before');
    $JSON->space_after(0) if $JSON->can('space_after');
    $JSON->canonical(0) if $JSON->can('canonical');
    $JSON_Implementation = $json_module;
    last if $JSON;
  }
}

sub new {
  my $class = shift;
  my %opt = @_;

  if (defined $opt{bins}) {
    my $bins = $opt{bins};
    croak("Cannot combine the 'bins' parameter with other parameters") if keys %opt > 1;
    croak("The 'bins' parameter needs to be a reference to an array of bins")
      if not ref($bins)
      or not ref($bins) eq 'ARRAY'
      or not @$bins > 1;
    return $class->_new_histo_bins($bins);
  }
  else {
    foreach (qw(min max nbins)) {
      croak("Need parameter '$_'") if not defined $opt{$_};
    }
  }

  return $class->_new_histo(@opt{qw(nbins min max)});
}

# See ExtUtils::Constant
sub AUTOLOAD {
  # This AUTOLOAD is used to 'autoload' constants from the constant()
  # XS function.

  my $constname;
  our $AUTOLOAD;
  ($constname = $AUTOLOAD) =~ s/.*:://;
  croak('&' . __PACKAGE__ . "::constant not defined") if $constname eq 'constant';
  my ($error, $val) = constant($constname);
  if ($error) { croak($error); }
  {
    no strict 'refs';
    *$AUTOLOAD = sub { $val };
  }
  goto &$AUTOLOAD;
}


use constant _PACK_FLAG_VARIABLE_BINS => 0;

sub dump {
  my $self = shift;
  my $type = shift;
  $type = lc($type);

  my ($min, $max, $nbins, $nfills, $overflow, $underflow, $data_ary, $bins_ary)
    = $self->_get_info;

  if ($type eq 'simple') {
    return join(
      ';',
      $VERSION,
      $min, $max, $nbins,
      $nfills, $overflow, $underflow,
      join('|', @$data_ary),
      (defined($bins_ary) ? join('|', @$bins_ary) : ''),
    );
  }
  elsif ($type eq 'json' or $type eq 'yaml') {
    my $struct = {
      version => $VERSION,
      min => $min, max => $max, nbins => $nbins,
      nfills => $nfills, overflow => $overflow, underflow => $underflow,
      data => $data_ary,
    };
    $struct->{bins} = $bins_ary if defined $bins_ary;

    if ($type eq 'json') {
      if (not defined $JSON) {
        die "Cannot use JSON dump mode since no JSON handling module could be loaded: "
            . join(', ', @JSON_Modules);
      }
      return $JSON->encode($struct);
    }
    else { # type eq yaml
      require YAML::Tiny;
      return YAML::Tiny::Dump($struct);
    }
  }
  elsif ($type eq 'native_pack') {
    my $flags = 0;
    vec($flags, _PACK_FLAG_VARIABLE_BINS, 1) = $bins_ary?1:0;

    return pack(
      'd3 V I2 d2 d*',
      $VERSION,
      $min, $max,
      $flags,
      $nbins,
      $nfills, $overflow, $underflow,
      @$data_ary,
      @{$bins_ary || []}
    );
  }
  else {
    croak("Unknown dump type: '$type'");
  }
  die "Must not be reached";
}


sub _check_version {
  my $version = shift;
  my $type = shift;
  if (not $version) {
    croak("Invalid '$type' dump format");
  }
  elsif ($VERSION-$version < -1.) {
    croak("Dump was generated with an incompatible newer version ($version) of this module ($VERSION)");
  }
}

sub new_from_dump {
  my $class = shift;
  my $type = shift;
  my $dump = shift;
  $type = lc($type);

  croak("Need dump string") if not defined $dump;

  my $version;
  my $hashref;
  if ($type eq 'simple') {
    ($version, my @rest) = split /;/, $dump, -1;
    my $nexpected = 9;

    _check_version($version, 'simple');
    if ($version <= 1.) { # no bins array in VERSION < 1
      $nexpected--;
    }
    elsif (@rest != $nexpected-1) {
      croak("Invalid 'simple' dump format, wrong number of elements in top level structure");
    }

    $hashref = {
      min => $rest[0], max => $rest[1], nbins => $rest[2],
      nfills => $rest[3], overflow => $rest[4], underflow => $rest[5],
      data => [split /\|/, $rest[6]]
    };
    if ($version >= 1. and $rest[7] ne '') {
      $hashref->{bins} = [split /\|/, $rest[7]];
    }
  }
  elsif ($type eq 'json') {
    if (not defined $JSON) {
      die "Cannot use JSON dump mode since no JSON handling module could be loaded: "
          . join(', ', @JSON_Modules);
    }
    $hashref = $JSON->decode($dump);
    $version = $hashref->{version};
    _check_version($version, 'json');
    croak("Invalid JSON dump, not a hashref") if not ref($hashref) eq 'HASH';
  }
  elsif ($type eq 'yaml') {
    require YAML::Tiny;
    my @docs = YAML::Tiny::Load($dump);
    if (@docs != 1 or not ref($docs[0]) eq 'HASH') {
      croak("Invalid YAML dump, not a single YAML document or not containing a hashref");
    }
    $hashref = $docs[0];
    $version = $hashref->{version};
    _check_version($version, 'yaml');
  }
  elsif ($type eq 'native_pack') {
    my $version = unpack('d', $dump);
    _check_version($version, 'native_pack');
    my $flags_support = $version >= 1.;
    my $pack_str = $flags_support ? 'd3 V I2 d2 d*' : 'd3 I2 d2 d*';
    my @things = unpack($pack_str, $dump);
    $version = shift @things;
    $hashref = {version => $version};

    foreach (qw(min max),
             ($flags_support ? ('flags') : ()),
             qw(nbins nfills overflow underflow))
    {
      $hashref->{$_} = shift(@things);
    }

    if ($flags_support) {
      my $flags = delete $hashref->{flags};
      if (vec($flags, _PACK_FLAG_VARIABLE_BINS, 1)) {
        $hashref->{bins} = [splice(@things, $hashref->{nbins})];
      }
    }

    $hashref->{data} = \@things;
  }
  else {
    croak("Unknown dump type: '$type'");
  }

  my $self;
  if (defined $hashref->{bins}) {
    $self = $class->new(bins => $hashref->{bins});
  }
  else {
    $self = $class->new(
      min   => $hashref->{min},
      max   => $hashref->{max},
      nbins => $hashref->{nbins},
    );
  }

  $self->set_nfills($hashref->{nfills});
  $self->set_overflow($hashref->{overflow});
  $self->set_underflow($hashref->{underflow});
  $self->set_all_bin_contents($hashref->{data});

  return $self;
}


sub STORABLE_freeze {
  my $self = shift;
  my $cloning = shift;
  my $serialized = $self->dump('simple');
  return $serialized;
}

sub STORABLE_thaw {
  my $self = shift;
  my $cloning = shift;
  my $serialized = shift;
  my $new = ref($self)->new_from_dump('simple', $serialized);
  $$self = $$new;
  # Pesky DESTROY :P
  bless($new => 'Math::SimpleHisto::XS::Doesntexist');
  $new = undef;
}

1;
__END__

=head1 NAME

Math::SimpleHisto::XS - Simple histogramming, but kinda fast

=head1 SYNOPSIS

  use Math::SimpleHisto::XS;
  my $hist = Math::SimpleHisto::XS->new(
    min => 10, max => 20, nbins => 1000,
  );
  
  $hist->fill($x);
  $hist->fill($x, $weight);
  $hist->fill(\@xs);
  $hist->fill(\@xs, \@ws);
  
  my $data_bins = $hist->all_bin_contents; # get bin contents as array ref
  my $bin_centers = $hist->bin_centers; # dito for the bins

=head1 DESCRIPTION

This module implements simple 1D histograms with fixed or
variable bin size. The implementation is mostly in C with a
thin Perl layer on top.

If this module isn't powerful enough for your histogramming needs,
have a look at the powerful-but-experimental L<SOOT> module or
submit a patch.

The lower bin boundary is considered part of the bin. The upper
bin boundary is considered part of the next bin or overflow.

Bin numbering starts at C<0>.

=head2 EXPORT

Nothing is exported by this module into the calling namespace by
default. You can choose to export the following constants:

  INTEGRAL_CONSTANT

Or you can use the import tag C<':all'> to import all.

=head1 FIXED- VS. VARIABLE-SIZE BINS

This module implements histograms with both fixed and variable
bin sizes. Fixed bin size means that all bins in the histogram
have the same size. Implementation-wise, this means that finding
a bin in the histogram, for example for filling,
takes constant time (O(1)).

For variable width histograms, each bin can have a different size.
Finding a bin is implemented with a binary search, which has
logarithmic run-time complexity in the number of bins O(log n).

=head1 BASIC METHODS

=head2 C<new>

Constructor, takes named arguments. In order to create a fixed bin size
histogram, the following parameters are mandatory:

=over 2

=item min

The lower boundary of the histogram.

=item max

The upper boundary of the histogram.

=item nbins

The number of bins in the histogram.

=back

On the other hand, for creating variable width bin size histograms,
you must provide B<only> the C<bins> parameter with a reference to
an array of C<nbins + 1> bin boundaries. For example,

  my $hist = Math::SimpleHisto::XS->new(
    bins => [1.5, 2.5, 4.0, 6.0, 8.5]
  );

creates a histogram with four bins:

  [1.5, 2.5)
  [2.5, 4.0)
  [4.0, 6.0)
  [6.0, 8.5)

=head2 C<clone>, C<new_alike>

C<$hist-E<gt>clone()> clones the object entirely.

C<$hist-E<gt>new_alike()> clones the parameters of the object,
but resets the contents of the clone.

=head2 C<fill>

Fill data into the histogram. Takes one or two arguments. The first must be the
coordinate that determines where data is to be added to the histogram.
The second is optional and can be a weight for the data to be added. It defaults
to C<1>.

If the coordinate is a reference to an array, it is assumed to contain many
data points that are to be filled into the histogram. In this case, if the
weight is used, it must also be a reference to an array of weights.

=head2 C<min>, C<max>, C<nbins>, C<width>

Return static histogram attributes: minimum coordinate, maximum coordinate,
number of bins, total width of the histogram, and the size of each bin.

=head2 C<underflow>, C<overflow>

Return the accumulated contents of the under- and overflow bins (which
have the ranges from C<(-inf, min)> and C<[max, inf)> respectively).

=head2 C<total>

The total sum of weights that have been filled into the histogram,
excluding under- and overflow.

=head2 C<nfills>

The total number of fill operations (currently including fills that fill into
under- and overflow, but this is subject to change).

=head1 BIN ACCESS METHODS

=head2 C<binsize>

Returns the size of a bin. For histograms with variable width bin sizes,
the size of the bin with the provided index is returned (defaults to the
first bin). Example:

  $hist->binsize(12);

Returns the size of the 13th bin.

=head2 C<all_bin_contents>, C<bin_content>

C<$hist-E<gt>all_bin_contents()> returns the contents of all histogram bins
as a reference to an array. This is not the internal storage but a copy.

C<$hist-E<gt>bin_content($ibin)> returns the content of a single bin.

=head2 C<bin_centers>, C<bin_center>

C<$hist-E<gt>bin_centers()> returns a reference to an array containing
the coordinates of all bin centers.

C<$hist-E<gt>bin_center($ibin)> returns the coordinate of the center
of a single bin.

=head2 C<bin_lower_boundaries>, C<bin_lower_boundary>

Same as C<bin_centers> and C<bin_center> respectively, but
for the lower boundary coordinate(s) of the bin(s). Note that
this lower boundary is considered part of the bin.

=head2 C<bin_upper_boundaries>, C<bin_upper_boundary>

Same as C<bin_centers> and C<bin_center> respectively, but
for the upper boundary coordinate(s) of the bin(s). Note that
this lower boundary is I<not> considered part of the bin.

=head2 C<find_bin>

C<$hist-E<gt>find_bin($x)> returns the bin number of the bin
in which the given coordinate falls. Returns undef if the
coordinate is outside the histogram range.

=head1 SETTERS

=head2 C<set_bin_content>

C<$hist-E<gt>set_bin_content($ibin, $content)> sets the content of a single bin.

=head2 C<set_underflow>, C<set_overflow>

C<$hist-E<gt>set_underflow($content)> sets the content of the underflow bin.
C<set_overflow> does the obvious.

=head2 C<set_nfills>

C<$hist-E<gt>set_nfills($n)> sets the number of fills.

=head2 C<set_all_bin_contents>

Given a reference to an array containing numbers, sets the contents
of each bin in the histogram to the number in the respective
array element. Number of elements needs to match the number of bins
in the histogram.

=head1 CALCULATIONS

=head2 C<integral>

Returns the integral over the histogram. I<Very limited at this point>. Usage:

  my $integral = $hist->integral($from, $to, TYPE);

Where C<$from> and C<$to> are the integration limits and the optional
C<TYPE> is a constant indicating the method to use for integration.
Currently, only C<INTEGRAL_CONSTANT> is implemented (and assumed as the
default). This means that the bins will be treated as rectangles,
but fractional bins are treated correctly.

If the integration limits are outside the histogram boundaries,
there is no warning, the integration is silently performed within
the range of the histogram.

=head2 C<mean>

Calculates the (weighted) mean of the histogram contents.

Note that the result is not usually the same as if you calculated
the mean of the input data directly due to the effect of the binning.

=head2 C<normalize>

Normalizes the histogram to the parameter of the
C<$hist-E<gt>normalize($total)> call.
Normalization defaults to C<1>.

=head1 SERIALIZATION

This class defines serialization hooks for the L<Storable>
module. Therefore, you can simply serialize objects using the
usual

  use Storable;
  my $string = Storable::nfreeze($histogram);
  # ... later ...
  my $histo_object = Storable::thaw($string);

Currently, this mechanism hardcodes the use of the C<simple>
dump format. This is subject to change!

The various serialization formats that this module supports (see
the C<dump> documentation below) all have various pros and cons.
For example, the C<native_pack> format is by far the fastest, but
is not portable. The C<simple> format is a very simple-minded text
format, but it is portable and performs well (comparable to the C<JSON>
format when using C<JSON::XS>, other JSON modules will be B<MUCH>
slower).
Of all formats, the C<YAML> format is the slowest. See
F<xt/bench_dumping.pl> for a simple benchmark script.

None of the serialization formats currently supports compression, but
the C<native_pack> format produces the smallest output at about half
the size of the JSON output. The C<simple> format is close
to C<JSON> for all but the smallest histograms, where it produces
slightly smaller dumps.
The C<YAML> produced is a bit bigger than the C<JSON>.

=head2 C<dump>

This module has fairly simple serialization methods. Just call the
C<dump> method on an object of this class and provide the type of
serialization desire. Currently valid serializations are
C<simple>, C<JSON>, C<YAML>, and C<native_pack>. Case doesn't matter.

For C<YAML> support, you need to have the C<YAML::Tiny> module
available. For C<JSON> support, you need any of C<JSON::XS>,
C<JSON::PP>, or C<JSON>. The three modules are tried in order
at I<compile> time. The chosen implementation can be
polled by looking at the
C<$Math::SimpleHisto::XS::JSON_Implementation> variable. It contains
the module name. Setting this vairable has no effect.

The simple serialization format is a home grown text format that
is subject to change, but in all likeliness, there will be some
form of version migration code in the deserializer for backwards
compatibility.

All of the serialization formats B<except for C<native_pack>>
are text-based and thus portable and endianness-neutral.

C<native_pack> should not be used when the serialized data
is transferred to another machine.

=head2 C<new_from_dump>

Given the type of the dump (C<simple>, C<JSON>, C<YAML>,
C<native_pack>) and the actual dump string, creates a new
histogram object from the contained data and returns it.

Deserializing C<JSON> and C<YAML> dumps requires
the respective support modules to be available. See above.

=head1 SEE ALSO

L<SOOT> is a dynamic wrapper around the ROOT C++ library
which does histogramming and much more. Beware, it is experimental
software.

Serialization can make use of the L<JSON::XS>, L<JSON::PP>,
L<JSON> or L<YAML::Tiny> modules.
You may want to use the convenient L<Storable> module for transparent
serialization of nested data structures containing objects
of this class.

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
