use 5.008001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $name = 'Math::SimpleHisto::XS';
my $define = '';
$define = '-Wall' if grep {/--debug/} @ARGV;

WriteMakefile(
    NAME              => $name,
    VERSION_FROM      => 'lib/Math/SimpleHisto/XS.pm', # finds $VERSION
    PREREQ_PM         => {
      #'ExtUtils::Constant' => '0',
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Math/SimpleHisto/XS.pm', # retrieve abstract from module
       AUTHOR         => 'Steffen Mueller <smueller@cpan.org>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => $define, # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);

if (eval "require ExtUtils::Constant; 1;") {
  open my $fh, '<', 'hist_constants.h'
    or die "Could not open 'hist_constants.h' for reading: $!";
  my @constants;
  while (<$fh>) {
    m{
      ^ \s* \# \s* define \s+
      (\w+) \s+
      [+-]?
      (?=\d|\.\d)
      \d*(?:\.\d*)?
      (?:[Ee][+-]?\d+)?
    }x or next;
    push @constants, $1;
  }

  ExtUtils::Constant::WriteConstants(
    NAME => $name,
    NAMES => \@constants,
  );
}

