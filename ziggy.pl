#!/usr/bin/perl -w

# Ziggy, the semicompetent nutbot
#
# Copyright (C) 2006 Jesse Morgan <ziggybot@morgajel.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# This bot is a clean-slate re-implementation- no direct code desendents 
# from Dicebot are included.
#
# A big thanks to BinGOs and dgnor for dealing with my noob questions,
# Andy Ruse for getting me to rework dicebot way back when, yojimbo for
# motivating me, shabbs for helping me with plugins, General for channel
# jumping, Ryn for brute forcing, and jaxon for letting me continue on with this.
#

#Goals
# I still need to work in the pluggable module system- I've taken the slabs
# of code from ziggy's old engine and placed them in module files. that's
# more or less my todo list. 

# TODO
# - remove all FIXME, TODO, and NOTEs from this file
# - config decides log.conf file
# - Comment better
# - nick recovery
# - TODO: create seperate logs for seperate channels/people
# - TODO: join different channels


use strict;
use POE;
use POE::Component::IRC::State;
use Data::Dumper;
use Digest::MD5;
use XML::Simple;
use FindBin;
use Readonly;
use Module::Reload;
use MIME::Lite;
use Log::Log4perl qw(get_logger :levels);
BEGIN{
push @INC, FindBin::again()."/modules";
push @INC, FindBin::again()."/lib";
}


#Common functions are located in the lib directory
use Common qw(filter authorized is_admin send_email generate_passwd username_available verify_email);


#-----------------------------------------------------------------
#------------------------ G L O B A L S --------------------------
#-----------------------------------------------------------------
# I'm not real fond of globals, but for these few items, it makes 
# sense since they're pretty much everywhere inside the code.


# ziggy's static config
# The XML file is loaded into here. This is the Personality of the bot.
# a lot more bounds checking should be done in code that relates to this
my $ziggy_config_ref;

#used only when needed- fairly new.
my $user_ref;

# ziggy's dynamic data- anything that is only stored for as long as he is 
# online. His short term memory, essentially.
my $ziggy_data=();
$ziggy_data->{'authorized_users'}={}; 


# These are my readonly constants join and part messages may later be added to
# FORCE_ARRAY_ELEMENTS. not sure yet
Readonly my $FORCE_ARRAY_ELEMENTS   =>[ "nick", "channel", "module" ,"user"];
Readonly my $USER_FILE_PATH         =>  FindBin::again() . "/users.xml";
my $configfile;
if (defined $ARGV[0] and  -e FindBin::again()."/".$ARGV[0] and $ARGV[0] ne ""){
    $configfile=  FindBin::again() ."/". $ARGV[0];
}else{
    $configfile=  FindBin::again() . "/config.xml";
}
Readonly my $CONFIG_FILE_PATH       =>  $configfile;


#------------------------ End   G L O B A L S --------------------------



#README You need to create a symbolic link that points to your own copy
# of the config file if you make changes to it- for example
# cp dribbly.xml mycopy.xml
# ln -s mycopy.xml config.xml
# why? so you can continue to use your config without borking mine.
&loadconfig();

Log::Log4perl->init_and_watch(FindBin::again()."/".$ziggy_config_ref->{'core'}->{'logconf'}, 30);
my $logger = get_logger("Ziggy");
$logger->info("logger initialized");

# Now that we've got the base config loaded, lets pull needed information from it
#-----------------------------------------------------------------


# Create the component that will represent an IRC network.
my ($irc) = POE::Component::IRC::State->spawn();



#-----------------------------------------------------------------


#=================================================================================================
#=================================================================================================
#========================  Now lets get to the serious code...  ==================================
#=================================================================================================
#=================================================================================================





# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.
POE::Session->create(
    inline_states => {
        _start              => \&bot_start,
        irc_433             => \&on_nick_taken,
        irc_001             => \&on_connect,
        register_w_nickserv => \&register_w_nickserv,
        irc_public          => \&on_public,
        say                 => \&say,
        act                 => \&act,
        irc_ctcp_action     => \&on_action,   
        irc_join            => \&on_join,
        irc_part            => \&on_part,
        irc_msg             => \&on_msg,
    # Below are custom ones I've created
    # They're not implemented here because they're
    # going to eventually be modules.
    #    wwbd                => \&wwbd,
    #    cueball             => \&cueball,
    #    barbrawl            => \&barbrawl,
    #    peterman            => \&peterman

    },
);

############################################################
## The following methods are state methods created above...


sub bot_start {
# The bot session has started.  Register this bot.
# IRC component.  Select a nickname.  Connect to a server.
    use vars qw ($ziggy_config_ref $ziggy_data);  #import $ziggy_config_ref to this scope
    my $kernel  = $_[KERNEL];  
	my $logger = get_logger("Ziggy->bot_start");


    $irc->yield( register => "all" );
    $ziggy_data->{'nick_in_use'}=0;
    $ziggy_data->{'attempted_nick'}=&select_nick();
    $irc->yield( connect =>
           { Nick     => $ziggy_data->{'attempted_nick'}->{'nickname'},
             Server   => $ziggy_config_ref->{'connect'}->{'server'},
             Port     => $ziggy_config_ref->{'connect'}->{'port'},
             Username => $ziggy_config_ref->{'connect'}->{'username'},
             Ircname  => $ziggy_config_ref->{'connect'}->{'realname'}, 
           }
    );

	# Lets also load our module plugin list.
	for my $my_mod (keys %{ $ziggy_config_ref->{'core'}->{'plugins'}->{'module'}}  ){
	    my $module= "$my_mod.pm";
	    # WARNING: this may or may not be dangerous- it's possible someone could tinker with 
	    # your config file to load an Evil module, but at that point, why not just own the code?
	    #
	    # Load the plugin module- useful for Module::Reload->check();
	    require $module; 
	
	    # when dumped, $plugin_obj returns
	    # $VAR1 = \bless( {}, 'bar_brawl' );
	    # which is what I'd expect
	    my $plugin_obj= \$my_mod->new(\$ziggy_config_ref,\$ziggy_data) ;
	    
	    $irc->plugin_add( $my_mod, $$plugin_obj);
	
	}
	
	$logger->info("The following modules are initially loaded:");
	foreach my $plugs( keys %{  $irc->plugin_list() }){
		$logger->info("-- $plugs;");
	}

}


sub on_nick_taken {
        # Thanks BinGOs
        # This will keep the bot from crashing when someone has it's name
        # check out the select_nick function for more details.
        use vars qw ($ziggy_config_ref $ziggy_data );  #import $ziggy_config_ref to this scope
        my ($kernel, $sender) = @_[ KERNEL , SENDER ];
		my $logger = get_logger("Ziggy->on_nick_taken");

		$logger->info("my nick(".$ziggy_data->{'attempted_nick'}->{'nickname'}.") was taken!");
        
        $ziggy_data->{'attempted_nick'}=&select_nick();
        
		$logger->info("Trying ".$ziggy_data->{'attempted_nick'}->{'nickname'}."...");
        $kernel->post( $sender , "nick" , $ziggy_data->{'attempted_nick'}->{'nickname'});
		$logger->debug( "tried to set nick, now what?");
#        This is for future functionality.
#        $kernel->delay( "recovernick" , 60 , $sender->ID() );
        undef; # not sure why this is here...
}





sub on_connect {
    # The bot has successfully connected to a server.  Join your channels.
    use vars qw ($ziggy_config_ref $ziggy_data );  #import $ziggy_config_ref to this scope
    my $kernel = $_[ KERNEL ];
	my $logger = get_logger("Ziggy->on_connect");
	$logger->debug("on connect'ing");

    foreach my $chan ( keys %{ $ziggy_config_ref->{'connect'}->{'channel'} } ){
        #join each channel listed in the config
		$logger->info("joining $chan");
        $irc->yield( join => $chan );
    }

    # this starts a delayed recursive loop that registers with nickserv.
    # If you're gonna have a bot own a channel, he needs to re-register every
    # so often. this is one way of doing that.

    if (exists  $ziggy_data->{'attempted_nick'}->{'password'} ){
          	$kernel->delay_add( 'register_w_nickserv', 0 );    #start now!
			$logger->info("need to activate registering...");
    }
	$logger->info("connect complete");

}


sub register_w_nickserv {
    # This is used to keep nickserv from forgetting who you are
    # If a bot is the Owner of a channel, it must log in regularly or lose ownership.
    # I debated making this a module, and perhaps I will some day and add 
    # support for X on Undernet. Until then, it'll stay here.
    use vars qw ($ziggy_config_ref $ziggy_data);  #import $ziggy_config_ref to this scope
    my ( $kernel ) = $_[ KERNEL ];
	my $logger = get_logger("Ziggy->register_w_nickserv");
        
    $logger->debug("Do I have a Password?");
	if (exists $ziggy_data->{'attempted_nick'}->{'password'}){
        $irc->yield( privmsg => "nickserv",'identify '.$ziggy_data->{'attempted_nick'}->{'password'} );
        $logger->info("I just messaged nickserv attempting to identify");
	}
   	$kernel->delay_add( 'register_w_nickserv', 60 * 60 * 24 );    #Run this every 24 hours
}



sub on_public {
    my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];
	my $logger = get_logger("Ziggy->on_public");

    $logger->info("<$nick:$channel> $msg");

    #place control structure HERE
    #
    # Proof of concept
    # for later: http://poe.perl.org/?POE_Cookbook/IRC_Plugins
    if( $msg =~/^list #(.*)/i){
        my $target_channel=$1;
        $logger->debug("$who asked for listing of $1");
        my @users= $irc->channel_list($target_channel);
        if (scalar (@users) >0){
            $kernel->delay_add( 'say',1,$nick,"in $1:  @users");
        }else{
            $kernel->delay_add( 'say',1,$nick,"sorry, I'm not in $1");
        }


    }else{
    # This section checks every line spoken by others to see if it contains a trigger.
    my $trigger_set=0;
        foreach my $trigger ( @{ $ziggy_config_ref->{'trigger'} } ) {
            # NOTE: trigger_text is treated as a regex
            my $trigger_text = $trigger->{'text'};

            if ( $msg =~ /$trigger_text/i ) {
                $logger->debug("$trigger_text was caught");
                my $users= [$irc->channel_list($channel)];
                # filter adds in variable replacement...
                my $response=&filter($trigger->{'content'},$nick,$users,$ziggy_data->{"attempted_nick"});
                $logger->debug("here's my response: \"$response\"");
                $kernel->delay_add( $trigger->{'type'},$trigger->{'delay'},$channel,$response );
                $trigger_set=1;
            }
        }
        my $randomizer_chance=int(rand($ziggy_config_ref->{'randomizer'}->{'chance'}));
        $logger->debug("print random if $randomizer_chance is ==1" );
        if (  $randomizer_chance==1  and  $trigger_set==0 ){
    
            $logger->debug("Something random");
            my @rand_sayings=@{$ziggy_config_ref->{'randomizer'}->{'random'}};
            my $saying=$rand_sayings[int(rand(scalar(@rand_sayings)))];
            my $botname=$ziggy_data->{'attempted_nick'};
                                 
            $saying->{'content'}=&filter($saying->{'content'},$nick,[$irc->channel_list($channel)],$botname);
            my $reply_type=$saying->{'type'}|'say';                        
            $kernel->delay_add( 
                $reply_type ,
                1,
                $channel,
                &filter($saying->{'content'},$nick,[$irc->channel_list($channel)],$botname)
            );
    
        }

    }

}

sub say{
    # I use say to put delay wrappers on saying and acting.
    # everything, except maybe games and feedback should use this wrapper 
    # with delay to make ziggy more human. same for act()
    #
    # Added new functionality to say and act- now can take an extra parameter of $delay.
    my ( $kernel, $target, $msg, $delay ) = @_[ KERNEL, ARG0, ARG1, ARG2];
	my $logger = get_logger("Ziggy->say");
        $logger->debug("======event running in 'say':");
        if ($delay>0){
            $logger->debug("delay Say:  $target  $msg   $delay");
            $kernel->delay_add( 'say', $delay,$target,$msg );
        
        }else{
            $logger->debug("in Say:  $target  $msg  ");
            $irc->yield( privmsg => $target, $msg );
        }
}


sub act{
    # I use say to put delays on conversations, and use this to keep it simple.
    # see comments on &say()
    my ( $kernel, $target, $msg, $delay ) = @_[ KERNEL, ARG0, ARG1, ARG2];
	my $logger = get_logger("Ziggy->act");

        if ($delay>0){
            $logger->debug("delay act:  $target  $msg   $delay");
            $kernel->delay_add( 'act', $delay,$target,$msg );
            
        }else{
            $logger->debug("in Act:  $target  $msg  ");
            #FIXME: this can be changed to a native command rather than privmsg
            $irc->yield( privmsg => $target, chr(1)."ACTION $msg".chr(1) );
        }
}


sub on_action() {
    my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
	my $logger = get_logger("Ziggy->on_action");
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

    my $ts = scalar localtime;
    $logger->info("<$nick:$channel> $msg");

    #place control structure HERE
    #
    # Proof of concept
    if ( $msg =~ /peterman/i ) {
        $logger->debug("fight time");
        # This should be using sparingly for hardcoding- leave it all for modules.
        # TODO: not implemented yet, will do it with a module instead of here.
        # $kernel->delay( 'barbrawl', (1+rand(3)),$channel );

    
    }

}


sub on_join {
    # This is triggered every time someone (including this bot) joins a channel 
    # the bot is in. can be used for greetings or perhaps a message system.
    use vars qw ($ziggy_config_ref $ziggy_data);
    my ( $kernel, $who, $channel ) = @_[ KERNEL, ARG0, ARG1];
	my $logger = get_logger("Ziggy->on_join");
    
    my $nick = ( split /!/, $who )[0];
    my $users= [$irc->channel_list($channel)];
    $logger->info("$nick just joined $channel");
    
    # The following determines how long and what percentage chance there is of joining a channel.
    if ((!exists $ziggy_data->{'last_join_wait'} || $ziggy_data->{'last_join_wait'}+$ziggy_config_ref->{'join'}->{'wait'} <time) and $ziggy_config_ref->{'join'}->{'active'} eq 'true') {
        # I check the size of users to make sure someone other than ziggy is in the channel.
        if (int (rand(100)) < $ziggy_config_ref->{'join'}->{'chance'} && scalar(@$users)>1){
            $ziggy_data->{'last_join_wait'}=time;
            my @join_sayings=@{$ziggy_config_ref->{'join'}->{'message'}};
            my $saying=&filter(@join_sayings[int(rand(scalar(@join_sayings)))]->{'content'},$nick,$users,$ziggy_data->{'attempted_nick'});
            $kernel->delay_add( 'say',(1+rand(4)),$channel,$saying );
        }
    }
}


sub on_part {
    # This is triggered every time someone (including this bot) parts a channel 
    # the bot is in. can be used for making fun of people (i.e. no real purpose)
    use vars qw ($ziggy_config_ref $ziggy_data);
    my ( $kernel, $who, $channel ) = @_[ KERNEL, ARG0, ARG1];
	my $logger = get_logger("Ziggy->on_part");
    
    my $nick = ( split /!/, $who )[0];
    my $users= [$irc->channel_list($channel)];
    $logger->info("$nick just parted $channel");
    
    # The following determines how long and what percentage chance there is of parting a channel.
    if ((!exists $ziggy_data->{'last_part_wait'} || $ziggy_data->{'last_part_wait'}+$ziggy_config_ref->{'part'}->{'wait'} <time)and $ziggy_config_ref->{'part'}->{'active'} eq 'true'){
        # I check the size of users to make sure someone other than ziggy is in the channel.
        if (int (rand(100)) < $ziggy_config_ref->{'part'}->{'chance'} && scalar(@$users)>1){
            $ziggy_data->{'last_part_wait'}=time;
            my @part_sayings=@{$ziggy_config_ref->{'part'}->{'message'}};
            my $saying=&filter(@part_sayings[int(rand(scalar(@part_sayings)))]->{'content'},$nick,$users,$ziggy_data->{'attempted_nick'});
            $kernel->delay_add( 'say',(1+rand(4)),$channel,$saying );
        }
    }
}





sub on_msg {
# Whenever someone messages ziggy, the message comes here.
# This is used for processing acting and saying things, as 
# well as identifing, registering and reloading configurations
    use vars qw ( $ziggy_config_ref $ziggy_data);
    my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
	my $logger = get_logger("Ziggy->on_msg");
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

    #we want to log everything except authentication
    if ( ($msg =~ /^(identify) ([^ ]+)/i ||  $msg =~ /^(changepw) ([^ ]+)/i ) 
        and   $channel eq $ziggy_data->{'attempted_nick'}->{'nickname'} ) {
        $logger->warn("* $nick attempts to  $1 ");
    }else{
        $logger->info("<$nick:$channel> $msg");
    }

#TODO: "spins the wheel ->points to ____"
#TODO: removemod and addmod to manage modules

                
    if ( $msg =~ /^act/i || $msg =~ /^say/i ) {
        # /m ziggy say #irc foo
        # allows an authorized user to speak or act as ziggy
        #FIXME: get rid of this garbage
        my ($garbage,$command, $channel, $talk ) = split( /^([^ ]+) +([^ ]+) +(.*)/, $msg );
        if (  &is_admin($user_ref, $ziggy_data, $who) ) {
            if ( $command eq "act" || $command eq "say") {
                $kernel->delay_add( $command,0,$channel,$talk );
            }
        }
        else {  $kernel->delay_add( 'say',0,$nick,"I'm sorry, you're not authorized." ); }

    }elsif ( $msg =~ /^reloadconf/i ) {
       #useful for troubleshooting- lets you reload config without restarting.
	   #FIXME: ziggy can't find isadmin -20060505
        if ( &is_admin($user_ref, $ziggy_data, $who) ) {
			$logger->debug("attempting to reload code");
            &loadconfig();
            $irc->yield( privmsg => $nick, "my config has been reloaded." );
        }else {  
            $irc->yield( privmsg => $nick, "I'm sorry, you're not authorized." ); 
        }
    
    }elsif ($msg =~/^reloadmodules/) {    
        if ( &is_admin($user_ref, $ziggy_data, $who) ) {
            &reloadmodules();
            $irc->yield( privmsg => $nick, "my modules have been reloaded." );
        }else {
            $irc->yield( privmsg => $nick, "I'm sorry, you're not authorized." );
        } 
    }elsif ( $msg =~ /^identify/i ) {
        # Allows a user to identify with ziggy.
        # Currently passwords are stored in a MD5 hash in ziggy's config.
        # to create an md5 hash, run this:
        # print Digest::MD5::md5_hex("my password");
        my ($garbage, $command, $username, $userpass ) = split( /^([^ ]+) +([^ ]+) +(.+)$/, $msg );
        if (exists $user_ref->{'user'}->{$username}          and
            $user_ref->{'user'}->{$username}->{'pass'} eq Digest::MD5::md5_hex($userpass) )
        {
            $kernel->delay_add( 'say',(1+rand(2)),$nick,"ok, you're logged in as $username. I'm filing it under $who" );
            # multiple who's can be logged in as a username(i.e. me from home and work can be lgged in as morgajel)
            $ziggy_data->{'authorized_users'}->{$who} = $username;
        }
        else {  $kernel->delay_add( 'say',(1+rand(3)),$nick,"nice try, but you're not $username. " ); }
        #I'm not sure why in the bloody hell I need that last (.*), but it doesn't work unless it's there.
        #oh well
    }elsif( $msg =~/^(chpw|changepass|changepw|chpass) +([^]+) +([^ ]+) +([^ ]+) +([^ ]+) +(.*)/i ){
        $logger->info("changing pw!\n");
        my $cmd=$1;
        my $username=$2;
        my $oldpass=$3;
        my $newpass=$4;
        my $newpassc=$5;
        if ($user_ref->{'user'}->{$username}->{'pass'} eq Digest::MD5::md5_hex($oldpass) and
            $newpass eq $newpassc   ){
            
            $user_ref->{'user'}->{$username}->{'pass'} = Digest::MD5::md5_hex($newpass);
            &saveusers();
                        
            $kernel->delay_add( 'say',1,$nick,"your password was changed." );
        
        }else{
            $logger->debug( " $cmd  $username  oldpass newpass newpassc  "); 
            $kernel->delay_add( 'say',1,$nick,"That don't parse. Check your spelling, make sure there's no extra spaces, and remember the format is \"changepw username oldpass newpass newpassconfirm\"" );
        
        }


    }elsif($msg =~ /help/){

		if($msg =~ /help *$/){
            $kernel->delay_add( 'say',0,$nick,"ok, I'm feeling especially nice today, so I'll give you the lowdown. " );
            $kernel->delay_add( 'say',0,$nick,"ask me about any of the following topics by typing \"help topic\": " );
            $kernel->delay_add( 'say',0,$nick,"account, administration, triggers" );
		
    	}elsif($msg =~ /help *(.*)/){

			if ($1 =~ /account/i ){
	            $kernel->delay_add('say',0,$nick,"Accounts:" );
	            $kernel->delay_add('say',0,$nick,"      registering: msg me with 'register username email' and I'll send you a message with a random password" );
	            $kernel->delay_add('say',0,$nick,"      identify: msg me with 'identify username password' to log in." );
	            $kernel->delay_add('say',0,$nick,"      change password: msg me with 'chpass oldpassword newpass newpass' to change your password." );
			}elsif ($1 =~ /administration/i ){
	            $kernel->delay_add( 'say',0,$nick,"Administration:" );
	            $kernel->delay_add( 'say',0,$nick,"      reloadconfig: reloads the ziggy_config_ref data from the config.xml" );
	            $kernel->delay_add( 'say',0,$nick,"      reloadmodules: reloads modules from the config list- useful if you remove modules from the config." );
	            $kernel->delay_add( 'say',0,$nick,"      say: msg me 'say #channel fooooo' and I will say that." );
	            $kernel->delay_add( 'say',0,$nick,"      act: msg me 'act #channel fooooo' and I will perform that action." );
			}elsif ($1 =~ /triggers/i ){
	            $kernel->delay_add( 'say',0,$nick,"Triggers:");
	            $kernel->delay_add( 'say',0,$nick,"      I have the following Triggers:");
            	for(my $i=0;$i < scalar(@{ $ziggy_config_ref->{'trigger'} }); $i++  ){
	                $kernel->delay_add( 'say',0,$nick,"      ".$ziggy_config_ref->{'trigger'}[$i]->{'text'}  );
	            }

    		}
		}
	    $kernel->delay_add( 'say',2,$nick,"You catch all that? Good- there will be a test later." );
 
        
        
        #register username email
    }elsif( $msg =~/^register ([^ ]+) (.*)/i ){
        my $username=$1;
        my $email=$2;
        $logger->info("ok, we're registering $username with $email");     
        if (&username_available($user_ref,$username)==1 and &verify_email($email)==1 ){
            $logger->debug("$username and $email are good.");
			$logger->info( "did email send? ".&send_email($user_ref,$username,$email));
            $kernel->delay_add( 'say',(1+rand(2)),$nick,"Alright, I sent you an email with your password. check it out and log in." );
            &saveusers();
        }else{
            $kernel->delay_add( 'say',(1+rand(2)),$nick,"Sorry, either $username was taken or $email was invalid." );
        
         # TODO: how should I guard against mass registrations?
        }# FIXME: should an email address be allowed for more than one account?
    
    }

}


# Run the bot until it is done.
$poe_kernel->run();
exit 0;




#======================================================================================================
#======================================================================================================
#======================================================================================================




sub select_nick {
    # get the next logical nick.
    # this is an ugly, multipurpose function that can be called for a couple of reasons.
    ######## first nick #########
    # attempted_nick should be empty.
    # if the first (0th) nick on original call, get that if it exists.
    # if it doesn't exist, the in_use number will be 0 or less. if it meets those conditions, try ZiggyClone###
    ####### the current nick is unavailable #######
    # attempted_nick should have data, so increment the pointer
    # if the newly pointed to nick exists, try using it.
    # if you've looped through previously and the newly pointed to nick doesn't exist, use the previous nick with ### appended

    use vars qw ($ziggy_config_ref $ziggy_data );  #import $ziggy_config_ref to this scope
	my $logger = get_logger("Ziggy->select_nick");


    if (exists $ziggy_data->{'attempted_nick'} ){
        $ziggy_data->{'nick_in_use'}++; #if attempted_nick has been tried before, increment
    }

    if (exists $ziggy_config_ref->{'connect'}->{'nick'}[$ziggy_data->{'nick_in_use'}]){
        $ziggy_data->{'attempted_nick'}=$ziggy_config_ref->{'connect'}->{'nick'}[$ziggy_data->{'nick_in_use'}];
    }elsif ($ziggy_data->{'nick_in_use'} >0){
        $ziggy_data->{'nick_in_use'}--;
        $ziggy_data->{'attempted_nick'}=$ziggy_config_ref->{'connect'}->{'nick'}[$ziggy_data->{'nick_in_use'}];
        $ziggy_data->{'attempted_nick'}->{'nickname'}=$ziggy_data->{'attempted_nick'}->{'nickname'}.int(rand 999);
    }else{
        $ziggy_data->{'attempted_nick'}->{'nickname'}="ZiggyClone".int(rand 999);
    }
    return $ziggy_data->{'attempted_nick'};
}


sub loadconfig {
    # This chunk of code it used during the initial load and when running
    # reloadconfig.
    use vars qw ($ziggy_config_ref $user_ref $FORCE_ARRAY_ELEMENTS $CONFIG_FILE_PATH $USER_FILE_PATH);
    my $xml = new XML::Simple;

    $ziggy_config_ref = $xml->XMLin(
        $CONFIG_FILE_PATH,
        ForceContent => 1,
        ForceArray   => $FORCE_ARRAY_ELEMENTS,
    );

    if (-e $USER_FILE_PATH){
        $user_ref = $xml->XMLin(
            $USER_FILE_PATH,
            ForceContent => 1,
            ForceArray   => $FORCE_ARRAY_ELEMENTS,
        ) ;
    }
    else{
        $user_ref->{'user'}={};
    }
}
sub saveusers{
    use vars qw ( $user_ref $FORCE_ARRAY_ELEMENTS $CONFIG_FILE_PATH $USER_FILE_PATH);
	my $logger = get_logger("Ziggy");
    my $xml = new XML::Simple;
    my $xmldata =$xml->XMLout($user_ref, RootName=>"registered_users");

    open USERFILE, ">$USER_FILE_PATH";
    print USERFILE "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n\n";
    print USERFILE "\n<!-- WARNING! this file is auto-generated. any non-tag additions (such as comments) will be 
     lost if you place them here. DO NOT COMMENT OUT LINES!!! -->\n\n";
    print USERFILE $xmldata;
    print USERFILE "<!-- last saved ".time." (".localtime().") -->\n";
    close USERFILE;

    $logger->info("$USER_FILE_PATH was saved successfully");

}


sub reloadmodules {
    # WARNING: this may or may not be dangerous- it's possible someone could tinker with 
    # your config file to load an Evil module, but at that point, why not just pwn the code?
	my $logger = get_logger("Ziggy");

    use vars qw ($ziggy_config_ref );
    #FIXED: I need to list all modules currently installed, not what's in the config!
    for my $my_mod (keys %{$irc->plugin_list() }){
        $logger->warn("removing plugin $my_mod");
        $irc->plugin_del( $my_mod);
        
    }

        Module::Reload->check;
    for my $my_mod (keys %{ $ziggy_config_ref->{'core'}->{'plugins'}->{'module'}}  ){
        $logger->warn("re-loading plugin $my_mod");
        my $module_tmp="$my_mod.pm";
        require $module_tmp;
        my $plugin_obj=\$my_mod->new(\$ziggy_config_ref,\$ziggy_data);
        $irc->plugin_add( $my_mod,$$plugin_obj);
        
    }
    $logger->info("the following modules are currently loaded:");
    foreach my $plugs( keys %{  $irc->plugin_list() }){
        $logger->info("-- $plugs;");
    }
}



# and that's it.

