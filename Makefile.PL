use strict;
use lib '.';
use inc::Module::Install;

name                ('SSH-Batch');
license             ('perl');
author              ('Agent Zhang <agentzh@yahoo.cn>');
perl_version        ('5.006001');
all_from            ('lib/SSH/Batch.pm');

requires            ('Set::Scalar'   => '1.23');
requires            ('File::HomeDir' => '0.86');
requires            ('Net::OpenSSH'  => '0.34');

build_requires      ('IPC::Run3');
build_requires      ('Test::Base' => '0.54');

no_index( directory => qw< t inc doc share demo > );

install_script      ('bin/fornodes');

auto_install();
WriteAll();

