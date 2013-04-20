#!/usr/bin/perl

package dndrules ;
{
    #my personality data structure
    my $ziggy_config_ref;
    # my short term memory
    my $ziggy_data;
    #see sample.pm for details on those two

    
    # Dumper and strict are useful modules, and Plugin is required.
	use Log::Log4perl qw(get_logger :levels );
    use Data::Dumper;
    use POE::Component::IRC::Plugin qw( :ALL );
    use strict;

    #Common functions are located in the lib directory
    use Common qw( filter );
    
	my $logger = get_logger("Ziggy::Facts");
    $logger->debug("loading dndrules");


    sub new {
        my ($package) = shift;
		my $logger = get_logger("Ziggy::Facts");
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Facts");
        $irc->plugin_register( $self, 'SERVER', qw( public msg) );
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
		my $logger = get_logger("Ziggy::DnD Rules");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        
        # if someone asks for a random rule and there is no last_dndrule or dndrule was a while ago
        if ( ($msg =~ /^!dndrule$/i or $msg =~ /^$botname[,:-;]? .* DnD Rule.*$/i  ) and
                (! defined $ziggy_data->{'last_dndrule'} ||
                $ziggy_data->{'last_dndrule'} +$ziggy_config_ref->{'dndrules'}->{'interval'}<time )   ){

            # set the last_dndrule to NOW.
            $ziggy_data->{'last_dndrule'}=time;
            $logger->info("DnD Rule was triggered");

            #grab all are phrases
	        my @dndrule_phrases = @{ $ziggy_config_ref->{'dndrules'}->{'option'} };
    	    #pick one phrase object
            my $random_phrase_obj = $dndrule_phrases[ rand( scalar(@dndrule_phrases) ) ];
            my $rulenumber = int( (rand(300000 )+5000)/1000 )*1000 +$random_phrase_obj->{'number'};
			my $random_phrase = "Rule #".$rulenumber.": ".$random_phrase_obj->{'content'};
            $logger->debug("I should say: $random_phrase");

            
            $irc->_send_event(
                    'say' ,
                    $channel ,
                    &filter($random_phrase,$nick,[$irc->channel_list($channel)],$botname ),
                    2+int(rand (2)) );
            
            # warning allow him to say "back off"
			$ziggy_data->{'dndrule_warning'}=0;
            return PCI_EAT_PLUGIN;
        }elsif(( $msg =~ /^!dndrule$/i or $msg =~ /^$botname[,:-;]? .* DnD Rule.*$/i  )
        and $ziggy_data->{'rule_warning'} < $ziggy_config_ref->{'dndrules'}->{'warning_count'}){
            # increment warning count; can I use ++ on a hash?
			$ziggy_data->{'dndrule_warning'}=$ziggy_data->{'dndrule_warning'} + 1;

            my $warning_text=$ziggy_config_ref->{'dndrules'}->{'warning'};

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
		my $logger = get_logger("Ziggy::DnD Rules");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for DnD Rules...");
		if( $msg =~/help/i ){
            if( $msg =~/help *dndrule *$/i ){
                $logger->info("help for DnD Rules...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "dndrules",1);
            }
            
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::DnD Rules");
        $irc->_send_event( 'say' ,  $target, "      DnD Rules:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  say \"[bot], blah blah DnD Rule blah\"",1);
        $irc->_send_event( 'say' ,  $target, "            Delay:     I only do it once every ".$ziggy_config_ref->{'dndrules'}->{'interval'}." seconds",1);
        $irc->_send_event( 'say' ,  $target, "            There are currently ".scalar( @{ $ziggy_config_ref->{'dndrules'}->{'option'} } )." dndrules in the database.",1);
   } 

    
#-----------------------------------------------------------
}
1;







