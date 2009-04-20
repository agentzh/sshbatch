package t::ForNodes;

use Test::Base -Base;
use IPC::Run3 ();
use FindBin;

our @EXPORT = qw( run_tests );

if (!-d 't/tmp') {
    mkdir 't/tmp';
}
$ENV{HOME} = "$FindBin::Bin/tmp";
#warn $ENV{HOME};
my $RcFile = $ENV{HOME} . '/.fornodesrc';

sub run_tests () {
    for my $block (blocks()) {
        run_test($block);
    }
}

sub write_rc (@) {
    open my $out, ">$RcFile" or
        die "Failed to open $RcFile for writing: $!\n";
    print $out @_;
    close $out;
}

sub run_test ($) {
    my $block = shift;
    my $name = $block->name;
    my $expr = $block->expr;
    chomp $expr;
    if (!defined $expr) {
        die "No --- expr specified.\n";
    }
    if (defined $block->rc) {
        write_rc($block->rc);
    } elsif (defined $block->no_rc) {
        unlink $RcFile;
    }
    my @cmd = ($^X, 'bin/fornodes', $expr);
    my ($in, $out, $err);
    IPC::Run3::run3 \@cmd, \$in, \$out, \$err;
    if (defined $block->status) {
        #warn "status: $?\n";
        is $? >> 8, $block->status, "$name - status ok";
    }
    if (defined $block->err) {
        $err =~ s/\Q$RcFile\E/**RC_FILE_PATH**/g;
        is $err, $block->err, "$name - stderr ok";
    } elsif ($err) {
        warn $err, "\n";
    }
    if (defined $block->out) {
        $out =~ s/\Q$RcFile\E/**RC_FILE_PATH**/g;
        is $out, $block->out, "$name - stdout ok";
    }
}

1;
