package Math::SimpleHisto::XS;
use 5.008001;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Math::SimpleHisto::XS', $VERSION);

sub new {
  my $class = shift;
  my %opt = @_;

  foreach (qw(min max nbins)) {
    croak("Need parameter '$_'") if not defined $opt{$_};
  }

  return $class->_new_histo(@opt{qw(nbins min max)})
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
  
  my $data_bins = $hist->all_bin_contents; # get bin contents

=head1 DESCRIPTION


=head1 SEE ALSO


=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
