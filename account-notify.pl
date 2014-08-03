#!/usr/bin/perl

use Irssi qw(signal_stop signal_emit signal_remove
             signal_add signal_add_first
             settings_add_str settings_get_str settings_add_bool
         settings_get_bool
             print );
use strict;

my %account_data;
my %saved_colors;
my %session_colors = {};
my @colors = qw/2 4 8 9 13 15/;
my(@format_identify_message_formats) = qw(pubmsg pubmsg_channel msg_private
                                          msg_private_query pubmsg_hilight
                                          pubmsg_hilight_channel action_private
                                          action_private_query action_public
                                          action_public_channel ctcp_requested
                                          ctcp_requested_unknown pubmsg_me
                                          pubmsg_me_channel
                                         );




Irssi::theme_register([
  'join', '{channick_hilight $0} {chanhost_hilight $1} has joined {channel $2}',
  'join_realname', '{channick_hilight $0} (realname: {hilight $1}) {chanhost_hilight $2} has joined {channel $3}',
  'join_account_realname', '{channick_hilight $0 [account: $1]} (realname: {hilight $2}) {chanhost_hilight $3} has joined {channel $4}',
]);

my %servers;

sub msg_join {
    my $target;
    my ($channel, $account, $realname);
    my ($server, $data, $nick, $host) = @_;

    if ($nick eq $server->{nick}) {
        if ($data=~/(\S+) (\S+) :(.*)/) {
            $channel=$1;
            $account=$2;
            $realname=$3;
        } else {
            if ($data=~/:(\S+)/) {
                $channel=$1;
            } else {
                $channel=$data;
            }
        }
        $server->print('', "ACCOUNT-NOTIFY: requesting account information for $channel.");

        $target=$channel;
        $server->redirect_event(
                'who', 1, '', 1, undef,
                {
                "event 354" => "redir account-notify_354",
                ""          => "event empty"
                }
                );

        $server->send_raw("WHO $target %na");
        return;
    }
    
    Irssi::signal_stop();

    if ($data=~/(\S+) (\S+) :(.*)/) {
        $channel=$1;
        $account=$2;
        $realname=$3;
        #Irssi::print("extended, channel $1, nick $nick account $2, realname $3");

        if ($account eq '*' || $account eq '0') {
            if (exists $account_data{$nick}) {
                delete $account_data{$nick};
            }
        } else {
            $account_data{$nick} = $account;
        }
    } else { 
        if ($data=~/:(\S+)/) {
            $channel=$1;
        } else {
            Irssi::print("SHOULD NOT BE HERE. data is $data and $nick is $nick.");
            $channel=$data;
        }

        if ($nick eq $server->{nick}) {
            $target=$data;
        } else {
            $target=$nick;
        }
        $server->redirect_event(
                'who', 1, '', 1, undef,
                {
                "event 354" => "redir account-notify_354",
                ""          => "event empty"
                }
                );

        $server->send_raw("WHO $target %na");
    }

    my $chanrec = $server->channel_find($channel);
    if ($chanrec && $realname && $account && $account ne '*') {
       $chanrec->printformat(MSGLEVEL_JOINS, 'join_account_realname', $nick, $account, $realname, $host, $channel);
    } elsif ($chanrec && $realname) {
       $chanrec->printformat(MSGLEVEL_JOINS, 'join_realname', $nick, $realname, $host, $channel);
    } elsif ($chanrec) {
       $chanrec->printformat(MSGLEVEL_JOINS, 'join', $nick, $host, $channel);
    }

    return;
}

sub event_account {
    my ($server, $account, $nick, $mask) = @_;



    my @chans = $server->channels();
    my @outchans = qw();
    foreach my $tmpchan (@chans) {
        my @nicks = $tmpchan->nicks();
        foreach my $tmpnick (@nicks) {
            if($tmpnick->{nick} eq $nick) {
                push(@outchans, $tmpchan);
                last;
            }
        }
    }

    my $message = "";
    if ($account eq '*' || $account eq '0') {
        if(exists $account_data{$nick}) {
            $message = "$nick is no longer authenticated, was $account_data{$nick}.";
            delete $account_data{$nick};
        } else {
            $message = "$nick is not authenticated.";
        }
    } else {
        if(exists $account_data{$nick} && $account_data{$nick} ne $account) {
            $message = "$nick was authenticated as $account_data{$nick}, and is now $account";
            delete $account_data{$nick};
        } else {
            $message = "$nick is now authenticated as $account.";
        }
        $account_data{$nick}=$account;
    }

    foreach my $tmpchan (@outchans) {
        $tmpchan->print($message);
    }

    return;
}

sub event_nick {
    my ($server, $newnick, $nick, $address) = @_;

    $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);
    
    if (exists $account_data{$newnick}) {
        Irssi::print("Warning! severe braindamage! $newnick already had account $account_data{$newnick}!");
        delete $account_data{$newnick};
    }

    if (exists $account_data{$nick}) {
        $account_data{$newnick} = $account_data{$nick};
        delete $account_data{$nick};
        my @chans = $server->channels();
        foreach my $tmpchan (@chans) {
            my @nicks = $tmpchan->nicks();
            foreach my $tmpnick (@nicks) {
                if($tmpnick->{nick} eq $nick || $tmpnick->{nick} eq $newnick) {
                    $tmpchan->print("Account $account_data{$newnick} ported from $nick to $newnick.");
                    last;
                }
            }
        }
    }
}

sub event_354 {
    my ($server, $data) = @_;
    my ($me, $nick, $account) = split(/ +/, $data, 7);

    if ($account eq '*' || $account eq '0') {
        if(exists $account_data{$nick}) {
            Irssi::print("$nick is no longer authenticated, was $account_data{$nick}.");
            delete $account_data{$nick};
        } else {
            #Irssi::print("$nick is still not authenticated.");
        }
    } else {
        if(exists $account_data{$nick} && $account_data{$nick} ne $account) {
            Irssi::print("$nick was authenticated as $account_data{$nick}, and is now $account");
            delete $account_data{$nick};
        } else {
            #Irssi::print("$nick is now authenticated as $account.");
        }
        $account_data{$nick}=$account;
    }
}

sub format_account_notify_message {
    my ($server, $data, $nick, $address) = @_;
    my ($channel, $msg) = split(/ :/, $data,2);
    my ($suffix) = "";

#my $chanref=$server->channel_find($channel);
#  if ($account_data{$nick}) {
#      Irssi::print("notify_message. $nick identified as $account_data{$nick}"); 
#  }ported 

    foreach my $format (@format_identify_message_formats) {
        if ($account_data{$nick}) {
            if (lc($account_data{$nick}) ne lc($nick)) {
                $suffix = "%G($account_data{$nick})";
            } else { 
                $suffix = "";
            }

            update_format_identify($server,$format,colourise($nick). '%U$0%U' . $suffix);
        } else {
            update_format_identify($server,$format,colourise($nick).'$0');
        }
    }
    format_identify_rewrite('event privmsg','format_account_notify_message', $server,$data,$nick,$address);
}

sub replace_format_identify {
    my ($format, $entry) = @_;

    my ($nickarg) = $format =~ /{\s*format_identify\s+?([^\s]+?)\s*}/;
    $entry =~ s/\$0/$nickarg/;
    $format =~ s/{\s*format_identify\s+?[^\s]+?\s*}/$entry/g;
    return $format;
}

# rewrite the message now that we've updated the formats
sub format_identify_rewrite {
    my $signal = shift;
    my $proc = shift;

    signal_stop();
    signal_remove($signal,$proc);
    signal_emit($signal, @_);
    signal_add($signal,$proc);
}


# Issue the format update after generating the new format.
sub update_format_identify {
    my ($server,$entry,$nick) = @_;

#
#  if ($account_data{$nick}) {
#    $nick="$nick($account_data{$nick})";
#  } else {
#      $nick="$nick(unknown)";
#  }

    my $identify_format = settings_get_str("${entry}_identify");
    my $replaced_format = replace_format_identify($identify_format,$nick);
    $server->command("^format $entry " . $replaced_format);
}

sub msg_nick {
    my ($server, $newnick, $nick, $address) = @_;
    if ($account_data{$nick}) {
        $account_data{$newnick}=$account_data{$nick};
        delete $account_data{$nick};
    }
}
#
sub event_cap {
    my ($server, $args, $nick, $address) = @_;
    my ($subcmd, $caps, $tosend);

    Irssi::print("received event_cap! hurray! $args ");

}

sub msg_quit {
    my ($server, $nick, $address, $data) = @_;
    if ($account_data{$nick}) {
        delete $account_data{$nick};
    }
}

sub account_notify_connected {
    my $server = shift;
    $server->print('', "ACCOUNT-NOTIFY: requesting caps: account-notify extended-join.");
    $server->send_raw_now("CAP REQ :account-notify extended-join");
}

Irssi::signal_add( {
        'event join' => \&msg_join,
        'event account' => \&event_account,
        'event cap' =>\&event_cap,
        'redir account-notify_354' => \&event_354,
        'event nick' => \&event_nick, 
        'event privmsg', 'format_account_notify_message',
        'event quit', \&msg_quit,
        'event connected', \&account_notify_connected
        });

sub simple_hash {
    my ($string) = @_;
    chomp $string;
    my @chars = split //, $string;
    my $counter;

    foreach my $char (@chars) {
        $counter += ord $char;
    }

    $counter = $colors[($counter % @colors)];
    return $counter;
}

sub colourise {
    return if(!settings_get_bool('format_colour'));
    my ($nick) = @_;
    my $color = $saved_colors{$nick};
    if (!$color) {
        $color = $session_colors{$nick};
    }
    if (!$color) {
        $color = simple_hash $nick;
        $session_colors{$nick} = $color;
    }
    $color = "0".$color if ($color < 10);
    return chr(3).$color;
}


foreach my $server (Irssi::servers()) {
#    %servers = ();
    account_notify_connected($server);
}


sub cmd_acno {
    my ($data, $server, $item) = @_;
    Irssi::print("\$data $data \$server $server \$item $item");
    $server->redirect_event(
            'who', 1, '', 1, undef,
            {
            "event 354" => "redir account-notify_354",
            ""          => "event empty"
            }
            );

    $server->send_raw("WHO $data %na");
}

Irssi::command_bind('acno', \&cmd_acno);


# How we format the nick.  $0 is the nick we'll be formating.
settings_add_str('format_identify','format_identified_nick','$0');
settings_add_str('format_identify','format_unidentified_nick','~$0');
settings_add_str('format_identify','format_unknown_nick','$0');
settings_add_bool('format_identify','format_colour',0);

# What we use for the formats...
# Don't modify here, use the /set command or modify in the ~/.irssi/config file.
settings_add_str('format_identify','pubmsg_identify','{pubmsgnick $2 {pubnick {format_identify $0}}}$1');
settings_add_str('format_identify','pubmsg_channel_identify','{pubmsgnick $3 {pubnick {format_identify $0}}{msgchannel $1}}$2');
settings_add_str('format_identify','msg_private_identify','{privmsg {format_identify $0} $1 }$2');
settings_add_str('format_identify','msg_private_query_identify','{privmsgnick {format_identify $0}}$2');
settings_add_str('format_identify','pubmsg_hilight_identify','{pubmsghinick {format_identify $0} $3 $1}$2');
settings_add_str('format_identify','pubmsg_hilight_channel_identify','{pubmsghinick {format_identify $0} $4 $1{msgchannel $2}$3');
settings_add_str('format_identify','action_private_identify','{pvtaction {format_identify $0}}$2');
settings_add_str('format_identify','action_private_query_identify','{pvtaction_query {format_identify $0}}$2');
settings_add_str('format_identify','action_public_identify','{pubaction {format_identify $0}}$1');
settings_add_str('format_identify','action_public_channel_identify', '{pubaction {format_identify $0}{msgchannel $1}}$2');
settings_add_str('format_identify','ctcp_requested_identify','{ctcp {hilight {format_identify $0}} {comment $1} requested CTCP {hilight $2} from {nick $4}}: $3');
settings_add_str('format_identify','ctcp_requested_unknown_identify','{ctcp {hilight {format_identify $0}} {comment $1} requested unknown CTCP {hilight $2} from {nick $4}}: $3');
settings_add_str('format_identify','pubmsg_me_identify','{pubmsgmenick $2 {menick {format_identify $0}}}$1');
settings_add_str('format_identify','pubmsg_me_channel_identify','{pubmsgmenick $3 {menick {format_identify $0}}{msgchannel $1}}$2');
settings_add_str('format_identify','notice_public_identify','{notice {format_identify $0}{pubnotice_channel $1}}$2');
settings_add_str('format_identify','notice_private_identify','{notice {format_identify $0}{pvtnotice_host $1}}$2');
settings_add_str('format_identify','ctcp_reply_identify','CTCP {hilight $0} reply from {nick {format_identify $1}}: $2');
settings_add_str('format_identify','ctcp_reply_channel_identify','CTCP {hilight $0} reply from {nick {format_identify $1}} in channel {channel $3}: $2');
settings_add_str('format_identify','ctcp_ping_reply_identify','CTCP {hilight PING} reply from {nick {format_identify $2}}: $1.$[-3.0]2 seconds');
