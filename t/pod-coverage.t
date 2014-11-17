# -*- cperl -*-
use strict;
use warnings;
use Test::More;

# These are used at top-level in bibtex.pm and the tests moan if it's not set.
use Biber::Config;
Biber::Config->setoption('vsplit', '_');
$Biber::Constants::CONFIG_SCOPE_BIBLATEX{variantforms} = {'GLOBAL' => 1};
Biber::Config->setblxoption('variantforms', []);

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

all_pod_coverage_ok();
