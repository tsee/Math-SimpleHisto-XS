package Math::SimpleHisto::XS;
use 5.008001;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.04'; # Committed to floating point version numbers!

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
our $JSON_Encoder;
our $JSON_Decoder;

foreach my $json_module (@JSON_Modules) {
  if (eval "require $json_module; 1;") {
    $JSON_Encoder = $json_module->can('encode_json');
    $JSON_Decoder = $json_module->can('decode_json');
    last if $JSON_Encoder and $JSON_Decoder;
  }
}

sub new {
  my $class = shift;
  my %opt = @_;

  foreach (qw(min max nbins)) {
    croak("Need parameter '$_'") if not defined $opt{$_};
  }

  return $class->_new_histo(@opt{qw(nbins min max)})
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


sub dump {
  my $self = shift;
  my $type = shift;
  $type = lc($type);

  my ($min, $max, $nbins, $nfills, $overflow, $underflow, $data_ary)
    = $self->_get_info;

  if ($type eq 'simple') {
    return join(
      ';',
      $VERSION,
      $min, $max, $nbins,
      $nfills, $overflow, $underflow,
      join('|', @$data_ary)
    );
  }
  elsif ($type eq 'json' or $type eq 'yaml') {
    my $struct = {
      version => $VERSION,
      min => $min, max => $max, nbins => $nbins,
      nfills => $nfills, overflow => $overflow, underflow => $underflow,
      data => $data_ary,
    };
    if ($type eq 'json') {
      if (not defined $JSON_Encoder) {
        die "Cannot use JSON dump mode since no JSON handling module could be loaded: "
            . join(', ', @JSON_Modules);
      }
      return $JSON_Encoder->($struct);
    }
    else { # type eq yaml
      require YAML::Tiny;
      return YAML::Tiny::Dump($struct);
    }
  }
  elsif ($type eq 'native_pack') {
    return pack(
      'd3 I2 d2 d*',
      $VERSION,
      $min, $max, $nbins,
      $nfills, $overflow, $underflow,
      @$data_ary
    );
  }
  else {
    croak("Unknown dump type: '$type'");
  }
  die "Must not be reached";
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
    ($version, my @rest) = split /;/, $dump;
    if (not $version) {
      croak("Invalid 'simple' dump format");
    }
    elsif (@rest != 7) {
      croak("Invalid 'simple' dump format, wrong number of elements in top level structure");
    }

    $hashref = {
      min => $rest[0], max => $rest[1], nbins => $rest[2],
      nfills => $rest[3], overflow => $rest[4], underflow => $rest[5],
      data => [split /\|/, $rest[6]]
    };
  }
  elsif ($type eq 'json') {
    if (not defined $JSON_Decoder) {
      die "Cannot use JSON dump mode since no JSON handling module could be loaded: "
          . join(', ', @JSON_Modules);
    }
    $hashref = $JSON_Decoder->($dump);
    $version = $hashref->{version};
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
  }
  elsif ($type eq 'native_pack') {
    my @things = unpack('d3 I2 d2 d*', $dump);
    $version = $things[0];
    $hashref = {};
    $hashref->{$_} = shift(@things) for qw(version min max nbins nfills overflow underflow);
    $hashref->{data} = \@things;
  }
  else {
    croak("Unknown dump type: '$type'");
  }

  if (not $version) {
    croak("Invalid '$type' dump format");
  }
  #elsif (... version incomptatibility ...) {}

  my $self = $class->new(
    min => $hashref->{min},
    max => $hashref->{max},
    nbins => $hashref->{nbins},
  );

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

This module implements simple 1D histograms with fixed bin size.
The implementation is mostly in C with a thin Perl layer on top.

If this module isn't powerful enough for your histogramming needs,
have a look at the powerful-but-experimental L<SOOT> module or
submit a patch.

The lower bin boundary is considered part of the bin. The upper
bin boundary is considered part of the next bin or overflow.

Bin numbering starts at C<0>.

=head2 EXPORT

Nothing is exported by this module into the calling namespace by
default. You can choose to export several constants:

  INTEGRAL_CONSTANT

Or you can use the import tag C<':all'> to import all.

=head1 BASIC METHODS

=head2 C<new>

Constructor, takes named arguments. Mandatory parameters:

=over 2

=item min

The lower boundary of the histogram.

=item max

The upper boundary of the histogram.

=item nbins

The number of bins in the histogram.

=back

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

=head2 C<min>, C<max>, C<nbins>, C<width>, C<binsize>

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

=head2 C<dump>

This module has fairly simple serialization methods. Just call the
C<dump> method on an object of this class and provide the type of
serialization desire. Currently valid serializations are
C<simple>, C<JSON>, and C<YAML>. Case doesn't matter.

For C<JSON> and C<YAML> support, you need to have the C<JSON>
and C<YAML::Tiny> modules available respectively.

The simple serialization format is a home grown text format that
is subject to change, but in all likeliness, there will be some
form of version migration code in the deserializer for backwards
compatibility.

All of the current serialization formats are text-based and thus
portable and endianness-neutral.

=head2 C<new_from_dump>

Given the type of the dump (C<simple>, C<JSON>, or C<YAML>)
and the actual dump string, creates a new histogram object
from the contained data and returns it.

Deserializing C<JSON> and C<YAML> dumps requires the
L<JSON> or L<YAML::Tiny> modules respectively.

=head1 SEE ALSO

L<SOOT> is a dynamic wrapper around the ROOT C++ library
which does histogramming and much more. Beware, it is experimental
software.

Serialization can make use of the L<JSON> or L<YAML::Tiny> modules.
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
