#!/usr/bin/perl

package wwzd ;
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
    use Common qw(filter);
    
	my $logger = get_logger("Ziggy::Wwzd");
    $logger->debug("loading wwzd");


    sub new {
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
		my $logger = get_logger("Ziggy::Wwzd");
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        $ziggy_data->{'last_wwzd'}=0;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Wwzd");
        $irc->plugin_register( $self, 'SERVER', qw( public msg ) );
        # check for public messages.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::Wwzd");
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Wwzd");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        # if someone asks a wwzd question and there is no last_wwzd or wwzd was a while ago
#        $logger->info("wwzd public...". ($ziggy_data->{'last_wwzd'}+$ziggy_config_ref->{'wwzd'}->{'interval'}  ));
        if ( ($msg =~ /what would $botname do\?$/i) and
                (! defined $ziggy_data->{'last_wwzd'} ||
                $ziggy_data->{'last_wwzd'} +$ziggy_config_ref->{'wwzd'}->{'interval'}<time )   ){

            # set the last_wwzd to NOW.
            $ziggy_data->{'last_wwzd'}=time;
            $logger->info("wwzd was triggered");

            #grab all are phrases
	        my @wwzd_phrases = @{ $ziggy_config_ref->{'wwzd'}->{'reply'} };
    	    #pick one phrase object
            my $random_phrase = $wwzd_phrases[ rand( scalar(@wwzd_phrases) ) ]->{'content'};

            my $content=&filter($random_phrase,$nick,[$irc->channel_list($channel)],$botname );
            my $wait=2+int(rand (2));
            $irc->delay([ privmsg =>  $channel => $content],$wait);
            
            # warning allow him to say "back off"
			$ziggy_data->{'wwzd_warning'}=0;
            return PCI_EAT_PLUGIN;
        }elsif(($msg =~ /what would $botname do\?$/i)
        and $ziggy_data->{'wwzd_warning'} < $ziggy_config_ref->{'wwzd'}->{'warning_count'}){
            # increment warning count; can I use ++ on a hash?
			$ziggy_data->{'wwzd_warning'}=$ziggy_data->{'wwzd_warning'} + 1;

            my $warning_text=$ziggy_config_ref->{'wwzd'}->{'warning'};
            my $content=&filter($warning_text,$nick,[$irc->channel_list($channel)],$botname );
            my $wait=2+int(rand (2));
            $irc->delay([ privmsg =>  $nick => $content],$wait);

            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }


    sub S_msg{
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Wwzd");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for wwzd...");
		if( $msg =~/help/i ){
            if( $msg =~/help *wwzd/i ){
                $logger->info("help for wwzd...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "wwzd",1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help{
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::Wwzd");
        $irc->_send_event( 'say' ,  $target, "      WWZD:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  say \"What would [bot] do?\"",1);
        $irc->_send_event( 'say' ,  $target, "            Delay:     I only do it once every ".$ziggy_config_ref->{'wwzd'}->{'interval'}." seconds",1);
   } 
    
#-----------------------------------------------------------
}
1;







