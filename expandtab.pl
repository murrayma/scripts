use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20021117;
use Text::Tabs;
$VERSION = '0.2';
%IRSSI = (
	authors  	=> 'Wouter Coekaerts and Hagbard',
	contact  	=> 'kd8lvz@logbook.am',
	name    	=> 'expandtab',
	description 	=> 'expands pasted tab characters out',
	license 	=> 'GPLv2',
	url     	=> 'http://localhost/',
	changed  	=> '03/06/13',
);

Irssi::signal_add_first('send command', \&expandtab);
Irssi::signal_add_first('send text', \&expandtab);
Irssi::signal_add_first('message public', \&expandtab2);

$tabstop = 4;

sub expandtab {
    my $tmp;
    $tmp = expand($_[0]);
	if ($tmp ne $_[0]) { 
        $_[0] = $tmp;
		Irssi::signal_continue(@_);
	}
};

sub expandtab2 {
    my $tmp;
    $tmp = expand($_[1]);
	if ($tmp ne $_[1]) { 
        $_[1] = $tmp;
		Irssi::signal_continue(@_);
	}
};


