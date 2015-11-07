# vi:filetype=

use t::atnodes;

plan tests => 3 * blocks();

#no_diff();

run_tests();

__DATA__

=== TEST 1: no home
--- no_home
--- args: ls *
--- err
Can't find the home for the current user.
--- out
--- status: 2



=== TEST 2: no rc given
--- args: ls *
--- no_rc
--- out
--- status: 0
--- SKIP

=== TEST 3: no args given
--- rc
api=api01.foo.com api02.foo.com
--- args:
--- out
--- err
No argument specified.

USAGE:

    atnodes [OPTIONS] COMMAND... -- HOST_PATTERN... [OPTIONS]
    atnodes [OPTIONS] COMMAND HOST_PATTERN... [OPTIONS]

OPTIONS:
    -c <num>      Set SSH concurrency limit. (default: 20,
                  when -tty is on, this setting will no use)
    -h            Print this help.
    -l            List the hosts and do nothing else.
    -L            Use the line-mode output format, i.e., prefixing
                  every output line with the machine name.
                  (could be controlled by the env SSH_BATCH_LINE_MODE)
    -p <port>     Port for the remote SSH service.
    -ssh <path>   Specify an alternate ssh program.
                  (This overrides the SSH_BATCH_SSH_CMD environment.)
    -t <timeout>  Specify timeout for net traffic.
    -u <user>     User account for SSH login.
    -v            Be verbose.
    -w            Prompt for password (used for login and sudo,
                  could be privided by SSH_BATCH_PASSWORD).
    -W            Prompt for password (like -w but conflict, just for sudo.
                  Never use -W together with -w, because -w will be ignored).
    -P            Prompt for passphrase (used for login,
                  could be privided by SSH_BATCH_PASSPHRASE).
    -tty          Pseudo-tty.
    -q            Run SSH in quiet mode
--- status: 1



=== TEST 4: no command
--- args: -- foo.com
--- out
--- err
No command specified.
--- status: 255



=== TEST 5: no expression
--- args: 'ls *'
--- out
--- err
No cluster expression specified.
--- status: 255



=== TEST 6: commands & expression
--- args: ls '*' -- foo.com '*.bar.cn' -l -v
--- rc
blah=foo
--- out
--- err
Command: [ls][*]
Cluster expression: foo.com *.bar.cn
Cluster set: foo.com
--- status: 0



=== TEST 7: option takes a value error
--- args: ls foo.com -u
--- out
--- err
ERROR: Option -u takes a value.
--- status: 1



=== TEST 8: -ssh <prog> option
--- args: -ssh foo ls foo.com -l -v
--- out
--- err
Command: [ls]
Using SSH program [foo].
Cluster expression: foo.com
Cluster set: foo.com
--- status: 0

