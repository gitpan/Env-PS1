package Env::PS1;

use strict;
use Carp;
use AutoLoader 'AUTOLOAD';

our $VERSION = 0.02;

sub import {
	my $class = shift;
	return unless @_;
	my ($caller) = caller;
	for (@_) {
		/^\$(.+)/ or croak qq/$class can't export "$_", try "\$$_"/;
		no strict 'refs';
		tie ${"$caller\::$1"}, $class, $1;
	}
}

sub TIESCALAR {
	my ($class, $var) = @_;
	my $self = bless {
		var    => $var || 'PS1',
		format => '',
	}, $class;
	$self->cache();
	return $self;
}

sub STORE {
	my $self = shift;
	$ENV{$$self{var}} = shift;
	$self->cache();
}

sub FETCH {
	my $self = shift;
	unless ($ENV{$$self{var}} eq $$self{format}) {
		$$self{format} = $ENV{$$self{var}};
		$$self{cache} = [ $self->cache($$self{format}) ];
	}
	my $string = join '', map { ref($_) ? $_->() : $_ } @{$$self{cache}};
	$string =~ s/(\\\!|\!)/($1 eq '!') ? '!!' : '!'/ge;
	return $string;
}

sub sprintf {
	my $format = pop;
	my $string = join '', map { ref($_) ? $_->() : $_ } Env::PS1->cache($format);
	$string =~ s/(\\\!|\!)/($1 eq '!') ? '!!' : '!'/ge;
	return $string;
}

our @user_info; # ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire)
our %map; # for custom stuff
our %alias = (
	'$' => 'dollar',
	'@' => 'D', t => 'D', T => 'D', A => 'D',
);

sub cache {
	my ($self, $format) = @_;
	return '' unless defined $format; # get rid of uninitialised warnings
	@user_info = getpwuid($>);
	my @parts;
	#print "# string: $format\n";
	while ($format =~ s/^(.*?)(\\\\|\\([aenr]|0\d\d)|\\(.))//s) {
		push @parts, $1 || '';
		if ($2 eq '\\\\') { push @parts, '\\' }
		elsif ($3) { push @parts, eval qq/"\\$3"/ }
		elsif (exists $map{$4}) { push @parts, $map{$4} }
		elsif (grep {$4 eq $_} qw/C D P/) { # special cases
			my $sub = $4 ;
			$format =~ s/^\{(.*?)\}//;
			push @parts, $self->$sub($sub, $1);
		}
		elsif ($4 eq '[' or $4 eq ']') { next }
		else {
			my $sub = exists($alias{$4}) ? $alias{$4} : $4 ;
			push @parts, $self->can($sub) ? ($self->$sub($4)) : "\\$4";
		}
	}
	push @parts, $format;
	my @cache = ('');
	for (@parts) { # join strings, push code refs
		if (ref $_ or ref $cache[-1]) { push @cache, $_ }
		else { $cache[-1] .= $_ }
	}
	return @cache;
}

## format subs

sub u { $user_info[0] }

sub w { return sub { $ENV{PWD} } }

sub W { 
	return sub {
		return '/' if $ENV{PWD} eq '/';
		$ENV{PWD} =~ m#([^/]*)/?$#;
		return $1;
	}
}

## others defined below for Autoload

1;

__END__

=head1 NAME

Env::PS1 - prompt string formatter

=head1 SYNOPSIS

	# use the import function
	use Env::PS1 qw/$PS1/;
	$ENV{PS1} = '\u@\h \$ ';
	print $PS1;
	$readline = <STDIN>;

	# or tie it yourself
	tie $prompt, 'Env::PS1', 'PS1';

=head1 DESCRIPTION

This package supplies variables that are "tied" to environment variables like
'PS1' and 'PS2', if read it takes the contents of the variable as a format string
like the ones B<bash(1)> uses to format the prompt.

It is intended to be used in combination with the various ReadLine packages.

=head1 EXPORT

You can request for arbitrary variables to be exported, they will be
tied to the environment variables of the same name.

=head1 METHODS

=over 4

=item C<sprintf($format)>

Returns the formatted string.

Using this method all the time is a lot B<less> efficient then
using the tied variable, because the tied variable caches parts
of the format that remain the same anyway.

=back

=head1 FORMAT

The format is copied from bash(1) because that's what it is supposed
to be compatible with. We made some private extensions which obviously 
are not portable.

Note that is not the prompt format specified by the posix spec, that one 
only knows "!" for istory number and "!!" for literal "!".

The following escape sequences are recognized:

=over 4

=item \a

The bell character, identical to "\007"

=item \d

The date in "Weekday Month Date" format

=item \D{format}

The date in strftime(3) format, uses L<POSIX>

=cut

sub d  {
	return sub {
		my $t = localtime;
		$t =~ m/^(\w+\s+\w+\s+\d+)/;
		return $1;
	}
}

sub D {
	use POSIX qw(strftime);
	my $format =
		($_[1] eq 't') ? '%H:%M:%S' :
		($_[1] eq 'T') ? '%I:%M:%S' :
		($_[1] eq '@') ? '%I:%M %p' :
		($_[1] eq 'A') ? '%H:%M'    : $_[2] ;

	return sub { strftime $format, localtime };
}

=item \e

The escape character, identical to "\033"

=item \n

Newline

=item \r

Carriage return

=item \s

The basename of $0

=cut

sub s {
	$0 =~ m#([^/]*)$#;
	return $1 || '';
}

=pod

=item \t

The current time in 24-hour format, identical to "\D{%H:%M:%S}"

=item \T

The current time in 12-hour format, identical to "\D{%I:%M:%S}"

=item \@

The current time in 12-hour am/pm format, identical to "\D{%I:%M %p}"

=item \A

The current time in short 24-hour format, identical to "\D{%H:%M}"

=item \u

The username of the current user

=item \w

The current working directory

=item \W

The basename of the current working directory

=item \$

"#" for effective uid is 0 (root), else "$"

=cut

sub dollar { ($user_info[2] == 0) ? '#' : '$' }

=item \0dd

The character corresponding to the octal number 0dd

=item \\

Literal backslash

=item \H

Hostname, uses L<Sys::Hostname>

=item \h

First part of the hostname

=cut

sub H {
	use Sys::Hostname;
	*H = \&hostname;
	return hostname;
}

sub h {
    $_[0]->H =~ /^(.*?)(\.|$)/;
    return $1;
}

=item \l

The basename of the (output) terminal device name,
uses POSIX, but won't be really portable.

=cut

sub L { # How platform dependent is this ?
	use POSIX qw/ttyname/;
	*L = sub { ttyname(STDOUT) };
	return L;
}

sub l {
	$_[0]->L =~ m#([^/]*)$#;
	return $1;
}

=item \[ \]

These are used to encapsulate a sequence of non-printing chars.
Since we don't need that, they are removed.

=back

=head2 Extensions

The following escapes are extensions not supported by bash, and are not portable:

=over 4

=item \L

The (output) terminal device name, uses POSIX, but won't be really portable.

=item \C{colour}

Insert the ANSI sequence for named colour.
Known colours are: black, red, green, yellow, blue, magenta, cyan and white;
background colours prefixed with "on_".
Also known are reset, bold, dark, underline, blink and reverse, although the
effect depends on the terminla you use.

Unless you want the whole commandline coloured yous should 
end your prompt with "\C{reset}".

Of course you can still use the "raw" ansi escape codes for these colours.

Note that "bold" is sometimes also known as "bright", so "\C{bold,black}"
will on some terminals render dark grey.

=cut

sub C {
	our %colours = (
		reset     => 00,
		bold      => 01,
		dark      => 02,
		underline => 04,
		blink     => 05,
		reverse   => 07,

		black   => 30,	on_black   => 40,
		red     => 31,	on_red     => 41,
		green   => 32,	on_green   => 42,
		yellow  => 33,	on_yellow  => 43,
		blue    => 34,	on_blue    => 44,
		magenta => 35,	on_magenta => 45,
		cyan    => 36,	on_cyan    => 46,
		white   => 37,	on_white    => 47,
	);

	*C = sub {
		my @attr = split ',', $_[2];
		#print "# $_[2] => \\e[" . join(';', map {$colours{lc($_)}} @attr) . "m\n";
		return "\e[" . join(';', map {$colours{lc($_)}} @attr) . "m";
	};
	C(@_);
}

=item \P{format}

Proc information.

I<All of these are unix specific>

=over 4

=item %a

Acpi AC status '+' or '-' for connected or not, linux specific

=item %b

Acpi battery status in mWh, linux specific

=item %L

Load average

=item %l

First number of the load average

=item %t

Acpi temperature, linux specific

=item %u

Uptime

=item %w

Number of users logged in

=back

=cut

# $ uptime
# 17:38:53 up  3:24,  2 users,  load average: 0.04, 0.10, 0.13

sub P {
	my ($self, undef, $format) = @_;
	my %code;
	$format =~ s/\%(.)/$code{$1}++; "'.\$proc{$1}.'"/ge;
	my @subs = grep exists($code{$_}), qw/a b t/;

	return sub {
		my %proc;
		for my $s (@subs) {
			my $sub = "P_$s";
			$proc{$s} = $self->$sub();
		}
		if (open UP, 'uptime|') {
			my $up = <UP>;
			close UP;
			$up =~ /up\s*(\d+:\d+)/ and $proc{u} = $1;
			$up =~ /(\d+)\s*user/     and $proc{w} = $1;
			$up =~ /((\d+\.\d+),\s*\d+\.\d+,\s*\d+\.\d+)/
				and @proc{'L', 'l'} = ($1, $2);
		}
		#use Data::Dumper; print "'$format'", Dumper \%proc, "\n";
		eval "'$format'"; # all in single quote, except for escapes
	}
}

sub P_a {
	open(AC,'/proc/acpi/ac_adapter/AC/state') or return '?';
	my $a = <AC>;
	close AC;
	return ( ($a =~ /on/) ? '+' : '-' );
}

sub P_b {
	open(BAT,'/proc/acpi/battery/BAT0/state') or return '?';
	my ($b) = grep /^remaining capacity:/, (<BAT>);
	close BAT;
	$b =~ /(\d+)/;
	return $1 || '0';
}

sub P_t {
	open(TH, '/proc/acpi/thermal_zone/THM/temperature') or return '?';
	my $t = <TH>;
	close TH;
	$t =~ /(\d+)/;
	return $1 || '0';
}

=back

=head2 Not implemented escapes

The following escapes are not implemented, most of them because they are
application specific.

=over 4

=item \j

The number of jobs currently managed by the shell

=item \v

The version of bash

=item \V

The release of bash, version + patchelvel

=item \!

The history number of this command, gets replaced by literal '!'
while a literal '!' gets replaces by '!!';
this makes the string a posix compatible prompt, thus it will work
if your readline module expects a posix prompt.

=item \#

The command number of this command (like history number, but minus the
lines read from the history file).

=back

=head2 Customizing

If you want to overload escapes or want to supply values for the application
specific escapes you can put them in C<%Env::PS1::map>, the key is the escape letter,
the value either a string or a CODE ref.

=head1 BUGS

Please mail the author if you encounter any bugs.

=head1 AUTHOR

Jaap Karssenberg || Pardus [Larus] E<lt>pardus@cpan.orgE<gt>

Copyright (c) 2004 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Env>,
L<Term::ReadLine::Zoid>

=cut

