
use strict;
use vars qw/$PS1 $PS2/;
use Test::More tests => 9;

use_ok('Env::PS1', '$PS1');

my @u_info = eval { getpwuid($>) }
	? ( getpwuid($>) ) : ( $ENV{USER} || $ENV{LOGNAME} );

$ENV{PS1} = '\Q \u \\\\ ';
print "# PS1: $PS1\n";
ok $PS1 eq '\Q '.$u_info[0].' \\ ', 'simple format';

$ENV{PS1} = '\\a\\n\\r\\007';
ok $PS1 eq "\a\n\r\a", 'perl format';

$PS1 = '\$';
ok $PS1 eq ($u_info[2] ? '$' : '#'), 'alias';

my $result = $u_info[0].'@foobar';
$PS1 = '\u@foobar';
ok $PS1 eq $result, 'STORE';

my ($format, $prompt) = ('\u@foobar', '');
tie $prompt, 'Env::PS1', \$format;
$format = '\u@foobar';
ok $prompt eq $result, 'SCALAR ref';

$format = '\C{red,on_green}dus\C{reset}';
$ENV{CLICOLOR} = 0;
ok $prompt eq 'dus', 'CLICOLOR';

ok Env::PS1->sprintf('\u@foobar') eq $result, 'E:PS1:sprintf';

no warnings;
$Env::PS1::map{v} = 3;
$PS1 = '\v';
ok $PS1 eq 3, 'map';
