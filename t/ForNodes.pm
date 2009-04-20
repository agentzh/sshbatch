package t::ForNodes;

use Test::Base -Base;

our @#XPORT = qw( run_tests );

sub run_tests () {
    for my $block (blocks()) {
        run_test($block);
    }
}

sub run_test ($) {
    my $block = shift;
    my $name = $block->name;
}

1;
