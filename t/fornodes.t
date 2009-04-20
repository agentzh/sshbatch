# vi:filetype=

use t::ForNodes;

plan tests => 3 * blocks();

run_tests();

__DATA__

=== TEST 1: no rc given
--- expr: foo
--- no_rc
--- out
--- err
Can't open **RC_FILE_PATH** for reading: No such file or directory
--- status: 2



=== TEST 2: no expr given
--- rc
api=api01.foo.com api02.foo.com
--- expr:
--- out
--- err
No argument specified.
--- status: 255



=== TEST 3: literal hosts
--- expr: foo.com bar.cn
--- err
--- out
bar.cn
foo.com
--- status: 0



=== TEST 4: unmatched wildcard ?
--- expr: api?.foo.com
--- out
--- err
--- status: 0



=== TEST 5: matched wildcard ?
--- expr: api??.foo.com
--- out
api01.foo.com
api02.foo.com
--- err
--- status: 0



=== TEST 6: wildcard *
--- expr: api*
--- err
--- out
api01.foo.com
api02.foo.com
--- status: 0



=== TEST 7: wildcard * with ?
--- expr: api?2.*.com
--- err
--- out
api02.foo.com
--- status: 0

