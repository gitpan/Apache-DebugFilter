use ExtUtils::MakeMaker;

require 5.006;
use Apache2;
use mod_perl 1.99;
use ModPerl::MM;
use Apache::TestMM qw(test clean);

# accept the configs from command line
Apache::TestMM::filter_args();

my @scripts = qw(t/TEST);
for (@scripts) {
    Apache::TestMM::generate_script($_);
    push @clean_files, $_;
}

my %require = (
    "Apache::Test" => "1.10", # ipv6 fixes
    "mod_perl"     => "1.9915",
);

ModPerl::MM::WriteMakefile(
    NAME          => "Apache::DebugFilter",
    VERSION_FROM  => "DebugFilter.pm",
    clean         => {
        FILES => "@clean_files",
    },
    ABSTRACT_FROM => 'DebugFilter.pm',
    AUTHOR        => 'Stas Bekman <stas@stason.org>',
    PREREQ_PM     => \%require,
    dist          => {
        PREOP        => 'pod2text DebugFilter.pm > $(DISTVNAME)/README',
        COMPRESS     => 'gzip -9f',
        SUFFIX       => '.gz',
        ZIP          => 'zip',
        ZIPFLAGS     => '-r',
        DIST_DEFAULT => 'tardist',
    },


);
