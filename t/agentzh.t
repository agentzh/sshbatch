use strict;
use warnings;

#use Smart::Comments::JSON '##';
use IPC::Run3 qw(run3);
#use List::MoreUtils qw( all );

my $should_skip;
BEGIN {
    $should_skip = ! $ENV{SSH_BATCH_TEST_AGENTZH};
};
use Test::More $should_skip ?
    (skip_all => "Should only be enabled by developers.") :
    ('no_plan');

sub sh ($) {
    my $cmd = shift;
    if (system($cmd) != 0) {
        die "Failed to execute $cmd. Abort.\n";
    }
}

sub fornodes (@) {
    my ($out, $err);
    run3 [$^X, 'bin/fornodes', @_], \undef, \$out, \$err;
    if ($? != 0) {
        warn "fornodes returns non-zero status: ", $? >> 8, "\n";
    }
    if ($err) {
        warn $err;
    }
    my @hosts = split /\n/ms, $out;
    return \@hosts;
}

sub tonodes (@) {
    my ($out, $err);
    run3 [$^X, 'bin/tonodes', @_], \undef, \$out, \$out;
    if ($? != 0) {
        warn "tonodes returns non-zero status: ", $? >> 8, "\n";
    }
    if ($err) {
        warn $err;
    }
    my @outs = split /^====+ [^=]+ ===+$/ms, $out;
    shift @outs;
    return \@outs;
}

sub atnodes (@) {
    my ($out, $err);
    run3 [$^X, 'bin/atnodes', @_], \undef, \$out, \$out;
    if ($? != 0) {
        warn "atnodes returns non-zero status: ", $? >> 8, "\n";
    }
    if ($err) {
        warn $err;
    }
    my @outs = split /^====+ [^=]+ ===+$/ms, $out;
    shift @outs;
    return \@outs;
}

sub atnodes2 (@) {
    my ($out, $err);
    run3 [$^X, 'bin/atnodes', @_], \undef, \$out, \$out;
    if ($? != 0) {
        warn "atnodes returns non-zero status: ", $? >> 8, "\n";
    }
    if ($err) {
        warn $err;
    }
    return $out;
}

sub gen_local_tree () {
    if (-d 't/tmp') {
        sh 'rm -rf t/tmp';
    }
    sh 'mkdir -p t/tmp';
    sh 'touch t/tmp/a.txt';
    sh 'touch t/tmp/b.txt';
    sh 'touch t/tmp/README';
    sh 'mkdir -p t/tmp/foo/bar';
    sh 'touch t/tmp/foo/INSTALL';
}

sub cleanup_remote_tree ($) {
    my $count = shift;
    my $outs = atnodes('rm -rf /tmp/tmp', '{tq}');
    is scalar(@$outs), $count, 'all hosts generate outputs';
    for my $out (@$outs) {
        like $out, qr/^\s*$/, 'rm successfuly';
    }
    $outs = atnodes('ls /tmp/tmp', '{tq}');
    is scalar(@$outs), $count, 'all hosts generate outputs';
    ## outs: @$outs
    for my $out (@$outs) {
        is $out, "\nRemote command returns status code 1.\nls: /tmp/tmp: No such file or directory\n\n",
            'directory already removed';
    }
}

my $hosts = fornodes('{tq}');
my $count = @$hosts;
ok $count > 3, "more than 3 hosts in {tq} (found $count)";

{
    my $out = atnodes2('exit 1', '{tq}', '-L');
    my @lines = split /\n/, $out;
    my $i = 0;
    for my $host (@$hosts) {
        like $lines[$i++],
            qr/^\Q$host\E: Remote command returns status code 1\.$/,
            'line mode works';
    }
}

{
    my $out = atnodes2('echo hello, world; echo hey', '{tq}', '-L');
    my @lines = split /\n/, $out;
    my $i = 0;
    for my $host (@$hosts) {
        like $lines[$i++],
            qr/^\Q$host\E: hello, world$/,
            'line mode works';
        like $lines[$i++],
            qr/^\Q$host\E: hey$/,
            'line mode works';
    }
}

{
    my $out = atnodes2('echo', '{tq}', '-L');
    my @lines = split /\n/, $out;
    my $i = 0;
    for my $host (@$hosts) {
        like $lines[$i++],
            qr/^\Q$host\E: $/,
            'line mode works';
    }
}

{
    my $out = atnodes2('echo -n', '{tq}', '-L');
    is $out, '', 'no output, no hostname';
}

cleanup_remote_tree($count);
my $outs = tonodes('-r', '-rsync', 't/tmp', '--', '{tq}', ':/tmp/');
for my $out (@$outs) {
    is $out, "\n\n", 'transfer successfuly';
}

$outs = atnodes('ls /tmp/tmp|sort', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';
## outs: @$outs
for my $out (@$outs) {
    is $out, "\nREADME\na.txt\nb.txt\nfoo\n\n",
        'only specified files uploaded';
}

cleanup_remote_tree($count);
gen_local_tree();

$outs = tonodes('-r', 't/tmp', '{tq}:/tmp/');
is scalar(@$outs), $count, 'all hosts generate outputs';

$outs = atnodes('ls /tmp/tmp|sort', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';
for my $out (@$outs) {
    is $out, "\nREADME\na.txt\nb.txt\nfoo\n\n", 'level 1 files expected';
}

$outs = atnodes('ls /tmp/tmp/foo|sort', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';

## outs: @$outs
for my $out (@$outs) {
    is $out, "\nINSTALL\nbar\n\n", 'level 1 files expected';
}

cleanup_remote_tree($count);

$outs = tonodes('t/tmp', '{tq}:/tmp/', '-v');
for my $out (@$outs) {
    is $out, "\n", 'transfer successfuly';
}

$outs = atnodes('ls /tmp/tmp', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';
## outs: @$outs
for my $out (@$outs) {
    is $out, "\nRemote command returns status code 1.\nls: /tmp/tmp: No such file or directory\n\n", 'no -r no cp';
}

cleanup_remote_tree($count);

$outs = atnodes('mkdir /tmp/tmp', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';

$outs = tonodes('t/tmp/a.txt', 't/tmp/b.txt', '--', '{tq}', ':/tmp/tmp/');
for my $out (@$outs) {
    is $out, "\n\n", 'transfer successfuly';
}

$outs = atnodes('ls /tmp/tmp|sort', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';
## outs: @$outs
for my $out (@$outs) {
    is $out, "\na.txt\nb.txt\n\n", 'only specified files uploaded';
}

cleanup_remote_tree($count);
$outs = atnodes('mkdir /tmp/tmp', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';

$outs = tonodes('t/tmp/*', '--', '{tq}', ':/tmp/tmp/');
## outs: @$outs
for my $out (@$outs) {
    is $out, "\n\n", 'transfer successfuly';
}

$outs = atnodes('ls /tmp/tmp|sort', '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';
for my $out (@$outs) {
    is $out, "\n\n", 'no glob no files';
}

$outs = tonodes('-g', 't/tmp/*', '--', '{tq}', ':/tmp/tmp/', '-c', 2, '-v');
for my $out (@$outs) {
    like $out, qr/^\s*$/s, 'transfer successfuly';
}

$outs = atnodes('ls /tmp/tmp|sort', '-c', 2, '{tq}');
is scalar(@$outs), $count, 'all hosts generate outputs';
## outs: @$outs
for my $out (@$outs) {
    is $out, "\nREADME\na.txt\nb.txt\n\n", 'only specified files uploaded';
}

warn "DONE.\n";
