use strict;
use lib '.';
use inc::Module::Install;

name                ('SSH-Batch');
license             ('bsd');
author              ('Zhang "agentzh" Yichun <agentzh@gmail.com>');
perl_version        ('5.006001');
all_from            ('lib/SSH/Batch.pm');

repository 'http://github.com/agentzh/sshbatch';

requires            ('Set::Scalar'   => '1.23');
requires            ('File::HomeDir');
requires            ('Net::OpenSSH'  => '0.34');
requires            ('File::Temp');
requires            ('Term::ReadKey' => '2.30');
requires            ('IO::Pty');

build_requires      ('IPC::Run3');
#build_requires      ('Test::Base' => '0.54');

use_test_base;

no_index( directory => qw< t inc doc share demo > );

install_script      ('bin/fornodes');
install_script      ('bin/atnodes');
install_script      ('bin/tonodes');
install_script      ('bin/key2nodes');

auto_install();
WriteAll();

