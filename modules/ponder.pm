#!/usr/bin/perl

package ponder ;
{
    #my personality data structure
    my $ziggy_config_ref;
    # my short term memory
    my $ziggy_data;
    #see sample.pm for details on those two

    
    # Dumper and strict are useful modules, and Plugin is required.
	use Log::Log4perl qw(get_logger);
    use Data::Dumper;
    use POE::Component::IRC::Plugin qw( :ALL );
    use strict;

    #Common functions are located in the lib directory
    use Common qw( filter );
    
	my $logger = get_logger("Ziggy::Ponder");
    $logger->debug("loading ponder");


    sub new {
        my ($package) = shift;
		my $logger = get_logger("Ziggy::Ponder");
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Ponder");
        $irc->plugin_register( $self, 'SERVER', qw( public msg ) );
        # check for public messages.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Ponder");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        # if someone ponders and there is no last_ponder or ponder was a while ago
        if ( ($msg =~ /^$botname. are you pondering what I'm pondering\?$/i) and
                (! defined $ziggy_data->{'last_ponder'} ||
                $ziggy_data->{'last_ponder'} +$ziggy_config_ref->{'ponder'}->{'interval'}<time )   ){

            # set the last_ponder to NOW.
            $ziggy_data->{'last_ponder'}=time;
            $logger->info("pondering was triggered");

            #grab all are phrases
	        my @ponder_phrases = @{ $ziggy_config_ref->{'ponder'}->{'reply'} };
    	    #pick one phrase object
            my $random_phrase = $ponder_phrases[ rand( scalar(@ponder_phrases) ) ]->{'content'};

            
            $irc->_send_event(
                    'say' ,
                    $channel ,
                    &filter($random_phrase,$nick,[$irc->channel_list($channel)],$botname ),
                    2+int(rand (2)) );
            
            # warning allow him to say "back off"
			$ziggy_data->{'ponder_warning'}=0;
            return PCI_EAT_PLUGIN;
        }elsif(($msg =~ /^$botname. are you pondering what I'm pondering\?$/i)
        and $ziggy_data->{'ponder_warning'} < $ziggy_config_ref->{'ponder'}->{'warning_count'}){
            # increment warning count; can I use ++ on a hash?
			$ziggy_data->{'ponder_warning'}=$ziggy_data->{'ponder_warning'} + 1;

            my $warning_text=$ziggy_config_ref->{'ponder'}->{'warning'};

            $irc->_send_event(
                    'say' ,   
                    $channel ,
                    &filter($warning_text,$nick,[$irc->channel_list($channel)],$botname ),
                    2+int(rand(2)) );


            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }


    sub S_msg {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Ponder");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for ponder...");
		if( $msg =~/help/i ){
            if( $msg =~/help *ponder/i ){
                $logger->info("help for ponder...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "ponder",1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::Ponder");
        $irc->_send_event( 'say' ,  $target, "      Ponder:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  say \"ziggy. are you pondering what I'm pondering?\"",1);
        $irc->_send_event( 'say' ,  $target, "            Delay:     I only do it once every ".$ziggy_config_ref->{'ponder'}->{'interval'}." seconds",1);
   } 
    
#-----------------------------------------------------------
}
1;







