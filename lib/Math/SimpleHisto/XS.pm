package Math::SimpleHisto::XS;
use 5.008001;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.01';

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
  my $type = shift || 'simple';

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
  else {
    croak("Unknown dump type: '$type'");
  }
  die "Must not be reached";
}

sub new_from_dump {
  my $class = shift;
  my $type = shift;
  my $dump = shift;

  croak("Need dump string") if not defined $dump;
  if ($type eq 'simple') {
    my ($version, @rest) = split /;/, $dump;
    if (not $version) {
      croak("Invalid 'simple' dump format");
    }
    elsif (@rest != 7) {
      croak("Invalid 'simple' dump format, wrong number of elements in top level structure");
    }
    my $self = $class->new(min => $rest[0], max => $rest[1], nbins => $rest[2]);
    $self->set_nfills($rest[3]);
    $self->set_overflow($rest[4]);
    $self->set_underflow($rest[5]);
    my $values = [split /\|/, $rest[6]];
    $self->set_all_bin_contents($values);
    return $self;
  }
  else {
    croak("Unknown dump type: '$type'");
  }
  die "Must not be reached";
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

=head2 C<clone>, C<new_alike>

C<$hist-E<gt>clone()> clones the object entirely.

C<$hist-E<gt>new_alike()> clones the parameters of the object,
but resets the contents of the clone.

=over 2

=item min

The lower boundary of the histogram.

=item max

The upper boundary of the histogram.

=item nbins

The number of bins in the histogram.

=back

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

=head1 SEE ALSO

L<SOOT> is a dynamic wrapper around the ROOT C++ library
which does histogramming and much more. Beware, it is experimental
software.

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
