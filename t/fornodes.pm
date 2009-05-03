package t::fornodes;

use Test::Base -Base;
use IPC::Run3 ();
use FindBin;

our @EXPORT = qw( run_tests );

if (!-d 't/tmp') {
    mkdir 't/tmp';
}
$ENV{LC_ALL} = 'C';
$ENV{SSH_BATCH_HOME} = "$FindBin::Bin/tmp";
#warn $ENV{SSH_BATCH_HOME};
my $RcFile = $ENV{SSH_BATCH_HOME} . '/.fornodesrc';

my $is_linux = ($^O =~ /linux/i);

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

    if (defined $block->linux_only && ! $is_linux) {
        diag "$name - Tests skipped on $^O\n";
        for (1..3) {
            pass("tests skipped on $^O\n");
        }
        return;
    }
    my $expr = $block->expr;
    if (defined $expr) { chomp $expr; }
    if (!defined $expr && !defined $block->opts) {
        die "Neither --- expr nor --- opts specified.\n";
    }
    if (defined $block->rc) {
        write_rc($block->rc);
    } elsif (defined $block->no_rc) {
        unlink $RcFile;
    }
    my $prev_home;
    if (defined $block->no_home) {
        $prev_home = $ENV{SSH_BATCH_HOME};
        $ENV{SSH_BATCH_HOME} = '/foo/bar/baz/32rdssfsd32';
    }
    my @opts;
    if (defined $block->opts) {
        @opts = split /\s+/, $block->opts;
    }
    my @cmd = ($^X, 'bin/fornodes', @opts, defined $expr ? $expr : ());
    my ($in, $out, $err);
    IPC::Run3::run3 \@cmd, \$in, \$out, \$err;
    if (defined $block->status) {
        #warn "status: $?\n";
        if ($block->status == 0) {
            is $? >> 8, $block->status, "$name - status ok";
        } else {
            ok($? >> 8, "$name - status ok");
        }
    }
    if (defined $block->no_home) {
        $ENV{SSH_BATCH_HOME} = $prev_home;
    }
    if (defined $block->err) {
        $err =~ s/\Q$RcFile\E/**RC_FILE_PATH**/g;
        is $err, $block->err, "$name - stderr ok";
    } elsif ($err) {
        warn $err, "\n";
    }
    if (defined $block->out) {
        $out =~ s/^\s+$//s;
        $out =~ s/\Q$RcFile\E/**RC_FILE_PATH**/g;
        is $out, $block->out, "$name - stdout ok";
    }
}

1;

