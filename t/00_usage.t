
use strict;
use vars qw/$PS1 $PS2/;
use Test::More tests => 7;

use_ok('Env::PS1', '$PS1');

my @u_info = getpwuid($>);

$ENV{PS1} = '\Q \u \\\\ ';
print "# PS1: $PS1\n";
ok $PS1 eq '\Q '.$u_info[0].' \\ ', 'simple format';

$ENV{PS1} = '\\a\\n\\r\\007';
ok $PS1 eq "\a\n\r\a", 'perl format';

ok Env::PS1->sprintf('\u@foobar') eq $u_info[0].'@foobar', 'E:PS1:sprintf';

$PS1 = '\u@foobar';
ok $PS1 eq $u_info[0].'@foobar', 'STORE';

$PS1 = '\$';
ok $PS1 eq ($u_info[2] ? '$' : '#'), 'alias';

no warnings;
$Env::PS1::map{v} = 3;
$PS1 = '\v';
ok $PS1 eq 3, 'map';
