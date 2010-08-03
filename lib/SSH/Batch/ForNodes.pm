package SSH::Batch::ForNodes;

use strict;
use warnings;

our $VERSION = '0.023';

use Set::Scalar;
use File::HomeDir;

sub clear_universe ();
sub init_rc ();
sub load_rc ($$);
sub parse_line ($$);
sub parse_expr ($);
sub parse_term ($);
sub parse_atom ($);
sub expand_seg ($@);
sub expand_wildcards ($);

my $RangePat = qr/\w+(?:(?:-|\.\.)\w+)?/;
my %Vars;
our $HostUniverse = Set::Scalar->new;

sub clear_universe () {
    $HostUniverse->empty;
}

sub init_rc () {
    my $home = $ENV{SSH_BATCH_HOME} || File::HomeDir->my_home;
    if (!defined $home || !-d $home) {
        die "Can't find the home for the current user.\n";
    }
    my $rcfile = "$home/.fornodesrc";

    # auto create $rcfile if $rcfile not exists
    if (! -e $rcfile) {
        open my $rc, '>', $rcfile or
            die "Can't auto create $rcfile: $!\n";
        close $rc;
    }

    open my $rc, $rcfile or
        die "Can't open $rcfile for reading: $!\n";
    load_rc($rc, $rcfile);
    close $rc;
    #return ($rc, $rcfile);
}

sub load_rc ($$) {
    my ($rc, $rcfile) = @_;
    my $accum_ln;
    while (<$rc>) {
        s/\#.*//;
        next if /^\s*$/;
        chomp;
        if (s/\\\s*$//s) {
            $accum_ln .= " $_";
            next;
        }
        if (defined $accum_ln) {
            parse_line("$accum_ln $_", $rcfile);
            undef $accum_ln;
            next;
        }
        parse_line($_, $rcfile);
    }
}

sub parse_line ($$) {
    local *_ = \($_[0]);
    my $rcfile = $_[1];
    if (/^\s*([^=\s]*)\s*=\s*(.*)/) {
        my ($var, $def) = ($1, $2);
        if ($var !~ /^[-\w]+$/) {
            die "Invalid variable name in $rcfile, line $.: ",
                "$var\n";
        }
        my $set;
        eval {
            $set = parse_expr($def);
        };
        if ($@) {
            die "Failed to parse the variable $var\'s value in $rcfile, ",
                "line $.: $@";
        } else {
            if (defined $Vars{$var}) {
                die "Variable redefinition in $rcfile line $.: $_\n";
            }
            $Vars{$var} = $set;
        }
    } else {
        die "Syntax error in $rcfile, line $.: $_\n";
    }
}

sub parse_expr ($) {
    local *_ = \($_[0]);
    my @toplevel;
    while (1) {
        if (/\G \s* (?<= [\}\)\s] ) ([-+*\/]) (?= [\{\(\s] ) \s*/gcx) {
            push @toplevel, $1;
        } elsif (/\G \{ .*? \} /gcx) {
            push @toplevel, $&;
        } elsif (/\G \S+ /gcx) {
            push @toplevel, $&;
        } elsif (/\G \s+ /gcx) {
            push @toplevel, '+';
        } else {
            last;
        }
    }
    my $expect_term = 1;
    for my $raw_op (@toplevel) { # op would be either operands or operators
        my $op = $raw_op;

        if ($op =~ /^[-+*\/]$/) {
            if ($expect_term) {
                die "Expecting terms but found operator $op.\n";
            }
            $expect_term = 1;
            next;
        }
        if (!$expect_term) {
            die "Expecting operators but found term $op\n";
        }
        $expect_term = 0;
        eval {
            $raw_op = parse_term($op);
        };
        if ($@) {
            die $@;
        }
    }
    my @lower;
    while (@toplevel > 1) {
        my $a = shift @toplevel;
        my $op = shift @toplevel;
        if ($op eq '+') {
            push @lower, $a, $op;
            #unshift @toplevel, $a + $b;
        } elsif ($op eq '-') {
            push @lower, $a, $op;
            #unshift @toplevel, $a - $b;
        } elsif ($op eq '*') {
            my $b = shift @toplevel;
            unshift @toplevel, $a * $b;
        } elsif ($op eq '/') {
            my $b = shift @toplevel;
            unshift @toplevel, $a / $b;
        } else {
            die "Invalid operator : [$op]\n";
        }
    }
    if (@toplevel) {
        push @lower, @toplevel;
    }
    while (@lower > 1) {
        my $a = shift @lower;
        my $op = shift @lower;
        my $b = shift @lower;

        if ($op eq '+') {
            unshift @lower, $a + $b;
        } elsif ($op eq '-') {
            unshift @lower, $a - $b;
        } else {
            die "Unexpected operator: [$op]\n";
        }
    }
    return @lower ? $lower[0] : Set::Scalar->new;
}

sub parse_term ($) {
    local *_ = \($_[0]);
    if (/^ \{ ( [^}\s]* ) \} $/x) {
        my $var = $1;
        if ($var !~ /^[-\w]+$/) {
            die "Invalid variable name in term $_: $var\n";
        }
        my $set = $Vars{$var};
        if (!defined $set) {
            die "Variable $var not defined.\n";
        }
        return $set;
    }
    if (/[{}]/) {
        die "Invalid variable reference syntax: $_\n";
    }
    return parse_atom($_);
}

sub parse_atom ($) {
    local *_ = \($_[0]);
    my @segs;
    while (1) {
        if (/ \G \[ ( [^\]]* ) \] /xgc) {
            my $range = $1;
            #warn "Range: $range\n";
            if ($range !~ m/^$RangePat(?:\s*,\s*$RangePat)*$/) {
                die "Bad range: [$range]\n";
            }
            my @ranges = split /,/, $range;
            my @num;
            for my $range (@ranges) {
                my ($a, $b) = split /(?:-|\.\.)/, $range;
                #if (defined $b && ($a =~ /\D/ || $b =~ /\D/) && length $a ne length $b) {
                    #die "End points are not of equal lengths in the host range: $a-$b\n";
                #}
                push @num, defined $b ? $a..$b : $a;
                #print "@num";
            }
            push @segs, \@num;
        } elsif (/\G[^\[]+/gc) {
            push @segs, [$&];
            next;
        } else {
            last;
        }
    }
    my $hosts = expand_seg(\@segs);
    my $set = Set::Scalar->new;
    for my $host (@$hosts) {
        #warn "Host: $host\n";
        if ($host =~ /[\*\?]/) {
            $set->insert(expand_wildcards($host));
        } else {
            #warn "Inserting $host: $host\n";
            $set->insert($host);
            $HostUniverse->insert($host);
        }
    }
    return $set;
}

sub expand_seg ($@) {
    my ($list, $prefixes) = @_;
    my $cur = shift @$list;
    return $prefixes unless defined $cur;
    my @new_prefixes;
    if (!$prefixes) {
        for my $alt (@$cur) {
            push @new_prefixes, $alt;
        }
    } else {
        for my $prefix (@$prefixes) {
            for my $alt (@$cur) {
                push @new_prefixes, $prefix . $alt;
            }
        }
    }
    return expand_seg($list, \@new_prefixes);
}

sub expand_wildcards ($) {
    my $pat = quotemeta $_[0];
    $pat =~ s/\\\*/.*?/g;
    $pat =~ s/\\\?/./g;
    my @retvals;
    while (defined(my $host = $HostUniverse->each)) {
        if ($host =~ /^$pat$/) {
            push @retvals, $host;
        }
    }
    return @retvals;
}

1;
__END__

=head1 NAME

SSH::Batch::ForNodes - Expand set arithmetic expression to host list

=head1 SYNOPSIS

    # below is essential what in the "fornodes" script:
    use SSH::Batch::ForNodes;

    SSH::Batch::ForNodes::init_rc();
    my $set = SSH::Batch::ForNodes::parse_expr($expr);
    # set is a Set::Scalar instance:
    for my $host (sort $set->elements) {
        print "$host\n";
    }

=head1 AUTHOR

Agent Zhang (agentzh) C<< <agentzh@yahoo.cn> >>

=head1 COPYRIGHT AND LICENSE

This module as well as its programs are licensed under the BSD License.

Copyright (c) 2009, Yahoo! China EEEE Works, Alibaba Inc. All rights reserved.

Copyright (C) 2009, Agent Zhang (agentzh). All rights reserved.

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

