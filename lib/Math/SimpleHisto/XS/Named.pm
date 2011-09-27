package Math::SimpleHisto::XS::Named;
use strict;
use warnings;
use Math::SimpleHisto::XS;

our $VERSION = '0.01';

use vars qw($AUTOLOAD);
use Carp qw(croak);

sub new {
  my $class = shift;
  my %param = @_;

  my $names = $param{names};
  croak("Need list of bin names!")
    if not $names or not ref($names) eq 'ARRAY';

  my $nbins = @$names;
  my $hist = Math::SimpleHisto::XS->new(
    nbins => $nbins,
    min   => 0,
    max   => $nbins,
  );

  my %namehash;
  my $i = 0;
  $namehash{$_} = $i++ for @$names;
  my $self = bless(
    {
      # careful about the cloning logic below and dump()
      hist => $hist,
      names => [@$names],
      namehash => \%namehash,
    } => $class
  );

  return $self;
}

# Generate bin-number-as-first-parameter delegation
foreach my $methname (qw(
  bin_content set_bin_content
  bin_center bin_lower_boundary bin_upper_boundary
  fill_by_bin
)) {
  my $sub = sub {
    my $self = shift;
    my $name = shift;
    die "Invalid bin name '$name'" if not exists $self->{namehash}{$name};
    my $ibin = $self->{namehash}{$name};
    return $self->{hist}->$methname($ibin, @_);
  };
  SCOPE: {
    no strict 'refs';
    *{"$methname"} = $sub;
  }
}

# generate cloning delegation
foreach my $methname (qw(clone new_alike)) {
  my $sub = sub {
    my $self = shift;
    my $clone = bless({
      %$self,
      names => [@{$self->{names}}],
      namehash => {%{$self->{namehash}}},
      hist => $self->{hist}->$methname(@_),
    } => ref($self));
    return $clone;
  };
  SCOPE: {
    no strict 'refs';
    *{"$methname"} = $sub;
  }
}

# Generate methods that croak because they make no sense
# on named bins
foreach my $methname (qw(
  find_bin min max binsize
  new_from_bin_range new_alike_from_bin_range
  integral
  rand
)) {
  my $sub = sub {
    croak("The '$methname' method makes little sense for named bins");
  };
  SCOPE: {
    no strict 'refs';
    *{"$methname"} = $sub;
  }
}



sub fill {
  my $self = shift;
  croak("Need at least one argument") if not @_;
  my ($x, $w) = @_;
  my $hist = $self->{hist};
  my $namehash = $self->{namehash};
  if (ref($x) eq 'ARRAY') {
    $x = [map $namehash->{$_}, @$x];
  }
  else {
    $x = $namehash->{$x};
  }
  return $hist->fill($x, defined($w) ? ($w) : ());
}

sub get_bin_names {
  return @{ $_[0]->{names} };
}

# Not a fan, but unless I find an elegant way to attach more data to the
# XS object, I can't think of anything else. Retrofitting XS::Object::Magic
# to the SimpleHisto implementation is too annoying.
sub AUTOLOAD {
  my $self = $_[0];

  my $methname = $AUTOLOAD;
  $methname =~ /^(.*)::([^:]+)$/ or die "Should not happen";
  (my $class, $methname) = ($1, $2);

  my $hist = $self->{hist};
  if ($hist->can($methname)) {
    my $delegate = sub {
      my $self = shift;
      return $self->{hist}->$methname(@_);
    };
    SCOPE: {
      no strict 'refs';
      *{"$methname"} = $delegate;
    }
    goto &$methname;
  }
  croak(qq{Can't locate object method "$methname" via package "$class"});
}

sub dump {
  my $self = shift;
  my $type = lc(shift);

  my $hist_dump = $self->{hist}->dump($type);

  my $rv = $Math::SimpleHisto::XS::JSON->encode({
    %$self,
    hist => $hist_dump,
    class => ref($self),
    histclass => ref($self->{hist})
  });
  return $rv;
}

sub new_from_dump {
  my $class = shift;
  my $type = lc(shift);
  my $data = shift;

  my $struct = $Math::SimpleHisto::XS::JSON->decode($data);
  $class = delete $struct->{class};
  my $hclass = delete $struct->{histclass};
  $struct->{hist} = $hclass->new_from_dump(delete $struct->{hist});
  return bless($struct => $class);
}

sub DESTROY {}

1;

__END__


=head1 NAME

Math::SimpleHisto::XS - Simple histogramming, but kinda fast

=head1 SYNOPSIS

  use Math::SimpleHisto::XS::Named;
  my $hist = Math::SimpleHisto::XS::Named->new(
    names => [qw(boys girls)],
  );
  $hist->fill('boys', 12);
  $hist->fill($_) for map $_->gender, @kids;

=head1 DESCRIPTION

B<EXPERIMENTAL>

This module provides histograms with named bins. It is built on top of
L<Math::SimpleHisto::XS> and attempts to provide the same interface as
far as it makes sense to support. The following documentation covers only
the differences between the two modules, so a basic familiarity with
C<Math::SimpleHisto::XS> is required.

It is important to not attempt to use a histogram with named bins by looking
at its internal coordinates or bin numbering.

=head1 API DIFFERENCES TO Math::SimpleHisto::XS

=head2 Constructor

The regular constructor, C<new> requires one parameter only: The

=head1 SEE ALSO

This module is built on top of L<Math::SimpleHisto::XS>.

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
