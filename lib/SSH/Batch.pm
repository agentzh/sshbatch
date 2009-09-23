package SSH::Batch;

use strict;
use warnings;

our $VERSION = '0.022';

1;
__END__

=head1 NAME

SSH::Batch - Cluster operations based on parallel SSH, set and interval arithmetic

=head1 VERSION

This document describes SSH::Batch 0.022 released on Sep 23, 2009.

=head1 SYNOPSIS

The following scripts are provided:

=over

=item fornodes

Expand patterns to machine host list.

    $ cat > ~/.fornodesrc
    ps=blah.ps.com bloo.ps.com boo[2-25,32,41-70].ps.com
    as=ws[1101-1105].as.com
    # use set operations to define new sets:
    foo={ps} + {ps} * {as} - {ps} / {as}
     bar = foo.com bar.org \
        bah.cn \
        baz.com
    ^D

    $ fornodes 'api[02-10].foo.bar.com' 'boo*.ps.com'
    $ fornodes 'tq[ab-ac].[1101-1105].foo.com'
    $ fornodes '{ps} + {as} - ws1104.as.com'  # set union and subtraction
    $ fornodes '{ps} * {as}'  # set intersect

=item atnodes

Run command on clusters. (atnodes calls fornodes internally.)

    # run a command on the specified servers:
    $ atnodes $'ps -fe|grep httpd' 'ws[1101-1105].as.com'

    # multiple-arg command requires "--":
    $ atnodes ls /opt/ -- '{ps} + {as}' 'localhost'

    # or use single arg command:
    $ atnodes 'ls /opt/' '{ps} + {as}' 'localhost' # ditto

    # specify a different user name and SSH server port:
    $ atnodes hostname '{ps}' -u agentz -p 12345

    # use -w to prompt for password if w/o SSH key (no echo back)
    $ atnodes hostname '{ps}' -u agentz -w

    # or prompt for password if sudo required...
    $ atnodes 'sudo apachectl restart' '{ps}' -w

    # or specify a timeout:
    $ atnodes 'ping foo.com' '{ps}' -t 3

=item tonodes

Upload local files/directories to remote clusters

    $ tonodes /tmp/*.inst -- '{as}:/tmp/'
    $ tonodes foo.txt 'ws1105*' :/tmp/bar.txt

    # use rsync instead of scp:
    $ tonodes foo.txt 'ws1105*' :/tmp/bar.txt -rsync

    $ tonodes -r /opt /bin/* -- 'ws[1101-1102].foo.com' 'bar.com' :/foo/bar/

=item key2nodes

Push the SSH public key (or generate one if not any) to the remote clusters.

    $ key2nodes 'ws[1101-1105].as.com'

=back

=head1 DESCRIPTION

System administration (sysadmin) is also part of my C<$work>. Playing with a (big) bunch of  machines without a handy tool is painful. So I refactored some of our old scripts and hence this module.

This is a high-level abstraction over the powerful L<Net::OpenSSH> module. A bunch of handy scripts are provided to simplify big cluster operations: L<fornodes>, L<atnodes>, L<tonodes>, and L<key2nodes>.

C<SSH::Batch> allows you to name your clusters using variables and interval/set syntax in your F<~/.fornodesrc> config file. For instance:

    $ cat ~/.fornodesrc
    A=foo[01-03].com bar.org
    B=bar.org baz[a-b,d,e-g].cn foo02.com
    C={A} * {B}
    D={A} - {B}

where cluster C<C> is the intersection set of cluster C<A> and C<B> while C<D> is the sef of machines that are in C<A> but not in C<B>.

And then you can query machine host list by using C<SSH::Batch>'s L<fornodes> script:

   $ fornodes '{C}'
   bar.org foo02.com

   $ fornodes '{D}'
   foo01.com foo03.com

   $ fornodes blah.com '{C} + {D}'
   bar.org blah.com foo01.com foo02.com foo03.com

It's always best practice to B<put spaces around set operators> like C<+>, C<->, C<*>, and C</>, so as to allow these characters (notably the dash C<->) in your host names, as in:

  $ fornodes 'foo-bar-[a-d].com - foo-bar-c.com'
  foo-bar-a.com foo-bar-b.com foo-bar-d.com

for the ranges like C<[a-z]>, there's also an alternative syntax:

   [a..z]

To exclude some discrete values from certain range, you need set subtration:

   foo[1-100].com - foo[32,56].com

or equivalently

   foo[1-31,33-55,57-100].com

L<fornodes> could be very handy in shell programming. For example, to test the 80 port HTTP service of a cluster C<A>, simply put

 $ for node in `fornodes '{A}'`; \
     do curl "http://$node:80/blah'; \
   done

Also, other scripts in this module, like L<atnodes>, L<tonodes>, and L<key2nodes> also call fornodes internally so that you can use the cluster spec syntax in those scripts' command line as well.

L<atnodes> meets the common requirement of running a command on a remote cluster. For example:

  # at the concurrency level of 6:
  atnodes 'ls -lh' '{A} + {B}' my.more.com -c 6

Or upload a local file to the remote cluster:

  tonodes ~/my.tar.gz '{A} / {B}' :/tmp/

or multiple files as well as some directories:

  tonodes -r ~/mydir ~/mydir2/*.so -- foo.com bar.cn :~/

It's also possible to use wildcards in the cluster spec expression, as in

  atnodes 'ls ~' 'api??.*.com'

where L<atnodes> will match the pattern C<api??.*.com> against the "universal set" consisting of those hosts appeared in F<~/fornodesrc> and those host names apeared before this pattern on the command line (if any). Note that only C<?> (match any character) and C<*> (match 0 or more characters) are supported here.

There's also a L<key2nodes> script to push SSH public keys to remote machines ;)

=head1 TIPS

There's some extra tips found in our own's everyday use:

=over

=item Running sudo commands

Often, we want to run commands requiring root access, such as when installing
software packages on remote machines. So you'll have to tell L<atnodes> to
prompt for your password:

  $ atnodes 'sudo yum install blah' '{my_cluster}' -w

Then you'll be prompted by the C<Password:> prompt after which you enter your
remote password (with echo back turned off).

Because the remote F<sshd> might be smart enough to "remember" the sudo password
for a (small) amount of time, immediate subsequent "sudo" might omit the C<-w> option, as in

  $ atnodes 'sudo mv ~/foo /usr/local/bin/' {my_cluster}

But remember, you can use I<sudo without passwords> just for a I<small> amount of
time ;)

If you see the following error message while doing sudo with L<atnodes>

  sudo: sorry, you must have a tty to run sudo

then you should probably comment out the "Defaults requiretty" line in your server's F</etc/sudoers> file (or just do this for your own account).

=item Passing custom options to the underlying C<ssh>

By default, C<atnodes> relies on L<Net::OpenSSH> to locate the OpenSSH client executable "ssh". But you can define the C<SSH_BATCH_SSH_CMD> environment to specify the command explicitly. You can use the C<-ssh> option to override it further. (The L<key2nodes> script also supports the C<SSH_BATCH_SSH_CMD> environment.)

Note that to specify your own "ssh" is also a way to pass more options to the underlying OpenSSH client executable when using C<atnodes>:

    $ cat > ~/bin/myssh
    #!/bin/sh
    # to enable X11 forwarding:
    exec ssh -X "$@"
    ^D

    $ chmod +x ~/bin/myssh

    $ export SSH_BATCH_SSH_CMD=~/bin/myssh
    $ atnodes 'ls -lh' '{my_cluster_name}'

It's important to use "exec" in your own ssh wrapper script, or you may see C<atnodes> hangs.

This trick also works for the L<key2nodes> script.

=item Use wildcard for cluster expressions to save typing

Wildcards in cluster spec could save a lot of typing. Say, if you have
C<api10.foo.bar.baz.bah.com.cn> appeared in your F<~/.fornodesrc> file:

  $ cat ~/.fornodesrc
  MyCluster=api[01-22].foo.bar.baz.bah.com.cn

then in case you want to refer to the C<api10.foo.bar.baz.bah.com.cn> node alone on the command line, you can just say C<api10*>, or C<api10.*.com.cn>, or something more specific.

But use wildcards with care. You may have nodes that you don't want in your
resulting host list. So it's best practice to use L<-l> option when you use
wildcards with L<atnodes> or L<tonodes>, as in

  $ atnodes 'rm -rf /opt/blah' 'api10*' -l

So that L<atnodes> will just echos out the exact host list that it would
operate on but without doing anything. (It's effectively a "dry-run".)
After checking, you can safely remove the C<-l> option and go on.

=item Specify a different ssh port or user name.

You may have already learned that you can use the C<-u> and C<-p> options to specify a non-default user account or SSH port. But it's also possible and often more convenient to put it as part of your cluster spec expression, either in F<~/.fornodesrc> or on the command line, as in

    $ cat > ~/.fornodesrc
    # cluster A uses the default user name:
    A=foo[01-25].com
    # cluster B uses the non-default user name "jim" and a port 12345
    B=jim@foo[26-28].com:12345

    $ atnodes 'ls -lh' '{B} + bob@bar[29-31].org:5678'

=item Use C<-L> to help grepping the outputs by hostname

When managing hundreds or even thousands of machines, it's often more
convenient to C<grep> over the outputs of L<atnodes> or L<tonodes> by
host names. The C<-L> option makes L<atnodes> and L<tonodes> to prefixing
every output lines of the remote commands (if any) by the host name. As in

  $ atnodes 'top -b|head -n5' '{my_big_cluster}' -L > out.txt 2>&1
  $ grep 'some.specific.host.com' out.txt

=item Specify a timeout to prevent hanging

It's often wise to specify a timeout for SSH operations. For example,
if there's 3 sec of network traffic silence, the following command will
quit with an error message printed:

  $ atnodes -t 3 'sleep 4' {my_cluster}

=item Limit the bandwith used by L<tonodes> to be firewall-friendly

You can use the C<-b> option to tell L<tonodes> to use limited bandwidth
if your intranet's Firewall is paranoid about your bandwidth use:

  $ tonodes my_big_file {my_cluster}:/tmp/ -b 8000

where C<8000> is in the unit of Kbits/sec, so it will not transfer
faster than 1 MByte/sec.

=item Avoid logging manually for the first time

When you use L<key2nodes> or L<atnodes> to access remote servers
that you have never logged in manually, you would probably see the
following errors:

 ===================== foo.com =====================
 Failed to spawn command.

 ERROR: unable to establish master SSH connection: the authenticity of the target host can't be established, try loging manually first

A work-around is using "ssh" to login to that C<foo.com> machine
manually and then try L<key2nodes> or L<atnodes> again.

Another nicer work-around is to pass the C<-o 'StrictHostKeyChecking=no'> option to the underlying F<ssh> executable used by C<SSH::Batch>.
Here's a quick HOW-TO:

    $ cat > ~/bin/myssh
    #!/bin/sh
    # to disable StrictHostKeyChecking
    exec ssh -o 'StrictHostKeyChecking=no' "$@"
    ^D

    $ chmod +x ~/bin/myssh

    $ export SSH_BATCH_SSH_CMD=~/bin/myssh

    # then we try again
    $ key2nodes foo.com
    $ atnodes 'hostname' foo.com

=back

=head1 PREREQUISITES

This module uses L<Net::OpenSSH> behind the scene, so it requires the OpenSSH I<client> executable (usually spelled "ssh") with multiplexing support (at least OpenSSH 4.1). To check your C<ssh> version, use the command:

    $ ssh -v

On my machine, it echos

    OpenSSH_4.7p1 Debian-8ubuntu1.2, OpenSSL 0.9.8g 19 Oct 2007
    usage: ssh [-1246AaCfgKkMNnqsTtVvXxY] [-b bind_address] [-c cipher_spec]
               [-D [bind_address:]port] [-e escape_char] [-F configfile]
               [-i identity_file] [-L [bind_address:]port:host:hostport]
               [-l login_name] [-m mac_spec] [-O ctl_cmd] [-o option] [-p port] [-R [bind_address:]port:host:hostport] [-S ctl_path]
               [-w local_tun[:remote_tun]] [user@]hostname [command]

There's no spesial requirement on the server side ssh service. Even a non-OpenSSH server-side deamon should work as well.

=head1 INSTALLATION

    perl Makefile.PL
    make
    make test
    sudo make install

Win32 users should replace "make" with "nmake".

=head1 SOURCE CONTROL

You can always get the latest SSH::Batch source from its
public Git repository:

    http://github.com/agentzh/sshbatch/tree/master

If you have a branch for me to pull, please let me know ;)

=head1 TODO

=over

=item *

Cache the parsing and evaluation results of the config file F<~/.fornodesrc>
to somewhere like the fiel F<~/.fornodesrc.cached>.

=item *

Abstract the duplicate code found in the scripts to a shared .pm file.

=item *

Add the F<fromnodes> script to help downloading files from the remote
clusters to local file system (maybe grouped by host name).

=item *

Add the F<betweennodes> script to transfer files between clusters through
localhost.

=back

=head1 SEE ALSO

L<fornodes>, L<atnodes>, L<tonodes>, L<key2nodes>,
L<SSH::Batch::ForNodes>, L<Net::OpenSSH>.

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

