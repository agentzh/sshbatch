package t::fornodes;

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
__END__

=head1 NAME

SSH::Batch::ForNodes - expands set arithmetic expression to host list

=head1 SYNOPSIS

    # below is essential what in the "fornodes" script:
    use SSH::Batch::ForNodes;

    my ($rc, $rcfile) = SSH::Batch::ForNodes::init();
    SSH::Batch::ForNodes::load_rc($rc, $rcfile);
    my $set = SSH::Batch::ForNodes::parse_expr($expr);
    for my $host (sort { $a cmp $b } $set->elements) {
        print "$host\n";
    }

=head1 AUTHOR

Agent Zhang (agentzh) C<< <agentzh@yahoo.cn> >>

=head1 COPYRIGHT AND LICENSE

This module as well as its programs are licensed under the BSD License.

Copyright (c) 2009, Yahoo! China EEEE Works, Alibaba Inc. All rights reserved.
Copyright (C) 2009, Agent Zhang (agentzh).

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

=over

=item *

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

=item *

Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

=item *

Neither the name of the Yahoo! China EEEE Works, Alibaba Inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

