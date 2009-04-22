# vi:filetype=

use t::fornodes;

plan tests => 3 * blocks();

no_diff();

run_tests();

__DATA__

=== TEST 1: no home
--- no_home
--- expr: abc
--- err
Can't find the home for the current user.
--- out
--- status: 2



=== TEST 2: no rc given
--- expr: foo
--- no_rc
--- out
--- err
Can't open **RC_FILE_PATH** for reading: No such file or directory
--- status: 2



=== TEST 3: no expr given
--- rc
api=api01.foo.com api02.foo.com
--- expr:
--- out
--- err
No argument specified.
--- status: 255



=== TEST 4: literal hosts
--- expr: foo.com bar.cn
--- err
--- out
bar.cn
foo.com
--- status: 0



=== TEST 5: unmatched wildcard ?
--- expr: api?.foo.com
--- out
--- err
--- status: 0



=== TEST 6: matched wildcard ?
--- expr: api??.foo.com
--- out
api01.foo.com
api02.foo.com
--- err
--- status: 0



=== TEST 7: wildcard *
--- expr: api*
--- err
--- out
api01.foo.com
api02.foo.com
--- status: 0



=== TEST 8: wildcard * with ?
--- expr: api?2.*.com
--- err
--- out
api02.foo.com
--- status: 0



=== TEST 9: variable reference
--- expr: {api}
--- err
--- out
api01.foo.com
api02.foo.com
--- status: 0



=== TEST 10: variable reference (with spaces)
--- expr: { api }
--- err
Invalid variable reference syntax: { api }
--- out
--- status: 255



=== TEST 11: set +
--- expr: {api} + {api}
--- err
--- out
api01.foo.com
api02.foo.com
--- status: 0



=== TEST 12: set -
--- expr: {api} - {api}
--- err
--- out
--- status: 0



=== TEST 13: set -
--- expr: {api} - api02*
--- err
--- out
api01.foo.com
--- status: 0



=== TEST 14: set -
--- expr: api02* - api01*
--- err
--- out
api02.foo.com
--- status: 0



=== TEST 15: set -
--- expr: api02* - {api}
--- err
--- out
--- status: 0



=== TEST 16: set *
--- expr: {api} * {api}
--- err
--- out
api01.foo.com
api02.foo.com
--- status: 0



=== TEST 17: set * (no space)
--- expr: {api}*{api}
--- err
--- out
api01.foo.com
api02.foo.com
--- status: 0



=== TEST 18: set *
--- expr: {api} * api02*
--- err
--- out
api02.foo.com
--- status: 0



=== TEST 19: no spaces around operators
--- expr: api.com-api.com
--- out
api.com-api.com
--- err
--- status: 0



=== TEST 20: no spaces around operators
--- expr: api.com+api.com
--- out
api.com+api.com
--- err
--- status: 0



=== TEST 21: multiple variable refs
--- rc
# .rc files...
api=api[01-03].foo.com
tq=tq[1101-1105,1011-1021].bar.cn +{api}
--- expr: {api}
--- out
api01.foo.com
api02.foo.com
api03.foo.com
--- err
--- status: 0



=== TEST 22: multiple variable refs
--- rc
# .rc files...
api=api[01-03].foo.com
tq=tq[1101-1105,1011-1021].bar.cn + {api}
--- expr: {tq}
--- out
api01.foo.com
api02.foo.com
api03.foo.com
tq1011.bar.cn
tq1012.bar.cn
tq1013.bar.cn
tq1014.bar.cn
tq1015.bar.cn
tq1016.bar.cn
tq1017.bar.cn
tq1018.bar.cn
tq1019.bar.cn
tq1020.bar.cn
tq1021.bar.cn
tq1101.bar.cn
tq1102.bar.cn
tq1103.bar.cn
tq1104.bar.cn
tq1105.bar.cn
--- err
--- status: 0



=== TEST 23: intersect
--- expr: {api} * {tq}
--- out
api01.foo.com
api02.foo.com
api03.foo.com
--- err
--- status: 0



=== TEST 24: subtraction
--- expr: {api} - {tq}
--- out
--- err
--- status: 0



=== TEST 25: subtraction (reversed)
--- expr: {tq} - {api}
--- out
tq1011.bar.cn
tq1012.bar.cn
tq1013.bar.cn
tq1014.bar.cn
tq1015.bar.cn
tq1016.bar.cn
tq1017.bar.cn
tq1018.bar.cn
tq1019.bar.cn
tq1020.bar.cn
tq1021.bar.cn
tq1101.bar.cn
tq1102.bar.cn
tq1103.bar.cn
tq1104.bar.cn
tq1105.bar.cn
--- err
--- status: 0



=== TEST 26: ranges with wildcards
--- expr: {tq} * tq[1102-1104]* - tq1103*
--- out
tq1102.bar.cn
tq1104.bar.cn
--- err
--- status: 0



=== TEST 27: ranges using '..'
--- expr: [a..c].com
--- out
a.com
b.com
c.com
--- err
--- status: 0



=== TEST 28: ranges using -
--- expr: [a-c].com
--- out
a.com
b.com
c.com
--- err
--- status: 0



=== TEST 29: more ranges
--- expr: [aa-ac].com
--- out
aa.com
ab.com
ac.com
--- err
--- status: 0



=== TEST 30: more ranges
--- expr: [9-12].com
--- out
10.com
11.com
12.com
9.com
--- err
--- status: 0



=== TEST 31: more ranges
--- expr: [9-10,11,12,13-14].com
--- out
10.com
11.com
12.com
13.com
14.com
9.com
--- err
--- status: 0



=== TEST 32: two ranges in one pattern
--- expr: [a-b].[1..2].com
--- out
a.1.com
a.2.com
b.1.com
b.2.com
--- err
--- status: 0



=== TEST 33: bad range
--- expr: [a-].com
--- err
Bad range: [a-]
--- out
--- status: 255



=== TEST 34: bad range (2)
--- expr: [a..].com
--- err
Bad range: [a..]
--- out
--- status: 255



=== TEST 35: bad range (3)
--- expr: [].com
--- err
Bad range: []
--- out
--- status: 255



=== TEST 36: not a bad range
--- expr: [a].com
--- err
--- out
a.com
--- status: 0



=== TEST 37: bug
--- expr: foo.com *.bar.cn
--- rc
foo=bar
--- out
foo.com
--- err
--- status: 0



=== TEST 38: operator precedence
--- expr: {A}-{B}*{C}
--- rc
A=a b c
B=b
C=c
--- out
a
b
c
--- err
--- status: 0



=== TEST 39: set division
--- expr: {A}/{B}
--- rc
A=a b c
B=b c d
--- out
a
d
--- err
--- status: 0



=== TEST 40: single-line comments in rc
--- expr: {A} + {B}
--- rc
#howdy
A=a c
  # blah...
B=b
--- out
a
b
c
--- err
--- status: 0



=== TEST 41: multi-line expressions (two lines)
--- expr: {A}
--- rc
 A = a b \
    c
--- out
a
b
c
--- err
--- status: 0



=== TEST 42: multi-line expressions (three lines)
--- expr: {A}
--- rc
 A = a b \
    c\
d
--- out
a
b
c
d
--- err
--- status: 0

