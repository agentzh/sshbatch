use Test::More;

# XXX we need more POD...
my $skip_all = 1;
eval "use Test::Pod::Coverage";
plan skip_all => "We know we don't have enough POD :(" if $skip_all;
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;
all_pod_coverage_ok();

