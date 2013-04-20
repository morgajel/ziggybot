#!/usr/bin/perl
# The following code is the urmom module

package urmom ;
{
#
#
#if $msg=~/mom/
#  for (each user)
#    if $msg=~/$user.*mom/
#      $user's mom's _______

# There are a couple of core functions to a ziggy module- some are required, 
# most are optional.
#  sub new
#   remember that plugins are objects used by the core ziggy script. New is called
#   by ziggy to instanciate a instance of this plugin.
#   
#  sub PCI_register
#   to be used, a module must be registered with ziggy's core session. when a 
#   module IS registered, this function is run, which tells the module which hooks
#   to listen to.
#   
#  sub PCI_unregister
#   the opposite of register; run when a module is unregistered.
#   
#  sub S_*
#   This family of functions represent actions that are taken when hooks are called;
#   for example, if a public message is said in a channel, the function S_public 
#   will be called on that event. For details, check here:
#   http://search.cpan.org/dist/POE-Component-IRC/lib/POE/Component/IRC/Plugin.pm
#
#  sub U_* 
#   closely related to S_* functions; still not sure the differences.
#   
#  sub _default
#   A special hook function- if the plugin is listening for hooks that do not have
#   their own U_* or S_* function, they end up here. deal with them accordingly.
#




    #Ziggy's Personality file is stored is an XML structure read in by XML Simple.
    # This object is stored as ziggy_config_ref. Consider this long term memory.
    # Changes will not be saved.
    my $ziggy_config_ref;
    
    # Ziggy's current status; brawl iterations, current nick, etc are store in 
    # ziggy_data. use this to store semi-important data- it's essentially his short
    # term memory. Changes will not be saved.
    my $ziggy_data;
    
    # Dumper and strict are useful modules, and Plugin is required.
	use Log::Log4perl qw(get_logger);
    use Data::Dumper;
    use strict;
    use POE::Component::IRC::Plugin qw( :ALL );
    

    #Common functions are located in the lib directory
    use Common qw(filter );



	my $logger = get_logger("Ziggy::UrMom");
    $logger->debug("loading urmom");  

    #your plugin is an object- treat it as such. it'll be passed a dereferenced
    # ziggy_config_ref and ziggy_data- use them as you will, but the rule of thumb
    # is ziggy_config_ref is read only, ziggy_data is writable
    sub new {
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
		my $logger = get_logger("Ziggy::UrMom");
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        # instanciate any object-level variables here if needed
        # $self->{version}="1.0";
        $ziggy_data->{'urmom'}={};
        $ziggy_data->{'urmom'}->{'nextup'}=0;
        
        return bless $self, $package;
    }

    # This is one of the special plugin functions. Here is where you'll state what actions 
    # to spy on. it's run whenever modules are loaded or reloaded.
    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::UrMom");
        # all events that you want to listen for, do so here.
        # you can use USER or SERVER, tho I'm not sure the differences.
        $irc->plugin_register( $self, 'SERVER', qw( public msg ) );
        # you can also use privmsg, kick, join, etc.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
# Whatever you're registering above, prefix it was a S_ or U_ (depending on register type)
# and call your function that.
# For example, we're catching a public server message (when someone speaks in a channel we're in)
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::UrMom");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};

        if ( $msg =~ /your mom/i       and       time > $ziggy_data->{'urmom'}->{'nextup'} ){
            my $delay=int rand(4)+1;
            # logger() is another one of my special functions- it makes debugging easier. 
            # Put them in when you need timestamps, or to mark important events.
            $logger->info("someone said your mom. interval:". $ziggy_config_ref->{'urmom'}->{'interval'}." nextup:".$ziggy_data->{'urmom'}->{'nextup'}." time:".time);
            
            # To say something immediately (which you should avoid), use yield():
            # $irc->yield( 'privmsg' , $channel , "hello there." );
            # yield() makes ziggy respond too quickly, and looks lame.
            
            # the other way to do it allows you to use a delay, but it's a little more involved...
            # It takes four parameters;
            # - type (say or act)
            # - target (channel or user)
            # - message ( message to be sent; note I'm using the filter function here.)
            # - delay (optional, should be at least 1 second to make his responses more human)
            my $saying=&get_saying();
            $irc->_send_event( 
                        'say' ,  # can be 'say' or 'act'
                        $channel , # the target- can be someone's nick for private message
                        &filter($saying,$nick,[$irc->channel_list($channel)],$botname ),
                        $delay );
            $ziggy_data->{'urmom'}->{'nextup'}=time+$ziggy_config_ref->{'urmom'}->{'interval'};
            # a word about &filter() before we go further- this function is available in the ziggy_common.pm
            # it takes 4 parameters:
            # - unparsed message
            # - nick who triggered (also called the target)
            # - name of the bot(ziggy,ziggyjr, etc)
            # the end result is he replaces tokens with random people in the channel.
            # check the source for token definitions

            # back to the current code- every hook handler needs to return *something*
            # PCI_EAT_PLUGIN tells the session not to let any other modules parse this command
            # there are a couple other options as well- check POE::Component::IRC::Plugins documentation
            # on the net for more details.
            return PCI_EAT_PLUGIN;
        }else{
            #since "sample" wasn't caught, we're going to return the EAT_NONE exit code, meaning other modules can munch on it.
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }

sub get_saying {
        use vars qw ($ziggy_config_ref $ziggy_data);
		my $logger = get_logger("Ziggy::UrMom");
        my $id=int rand(scalar (@{ $ziggy_config_ref->{'urmom'}->{'saying'} } ));
        my $saying=$ziggy_config_ref->{'urmom'}->{'saying'}[$id]->{'content'};
        if ($ziggy_config_ref->{'urmom'}->{'intro_chance'} >= int(rand(100))){
            $logger->info("adding an intro...");
          my $intro_id= int(  rand(  scalar (  @{ $ziggy_config_ref->{'urmom'}->{'intro'}  }  )   )   );
          $saying=$ziggy_config_ref->{'urmom'}->{'intro'}[$intro_id]->{'content'} . $saying;
        
        }
        return $saying;

}
    

    sub S_msg {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::UrMom");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
		if( $msg =~/help/i ){
            if( $msg =~/help *ur *mom/i ){
                $logger->info("help for urmom...");
                &help($ziggy_config_ref,$nick,$irc);
        		$logger->info("help for urmom...");
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "urmom",1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::UrMom");
        $irc->_send_event( 'say' ,  $target, "      urmom:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  mention \"your mom\"",1);
        $irc->_send_event( 'say' ,  $target, "            Comments:  This module is dedicated to drutro.",1);
   } 
#-----------------------------------------------------------






}
1;
