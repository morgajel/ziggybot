#!/usr/bin/perl
#today's secret word is "______"
#________
#AAAAAAAAAAAAAHHHHHHHHHHHHHHHHHH!!!!

package secretword;
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
    use Common qw(filter authorized );
	
	my $logger = get_logger("Ziggy::SecretWord");
    $logger->debug("loading secretword");


    sub new {
		my $logger = get_logger("Ziggy::SecretWord");
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        bless $self, $package;
        &change_word_loop();

		return $self;
    }

    sub PCI_register {
		my $logger = get_logger("Ziggy::SecretWord");
        my ( $self, $irc ) = splice @_, 0, 2;
        $irc->plugin_register( $self, 'SERVER', qw( public msg ) );
        # check for public messages.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::SecretWord");
        return 1;
    }


	sub change_secret_word {
	
		my ( $ziggy_config_ref,$ziggy_data)=@_;
			my $logger = get_logger("Ziggy::SecretWord");
		#secret wordlist minus the current secret word	
		my @secret_list    =@{ 
					[grep { $_->{'content'} ne $ziggy_data->{'secret_word'}->{'word'} }  
						@{ $ziggy_config_ref->{'secret_word'}->{'list'} }   
					]  
				} ;
	
	    #	$logger->debug("Secret word choices are:     ".Dumper(@secret_list));
		$ziggy_data->{'secret_word'}->{'word'}= $secret_list[ int(rand(scalar(@secret_list))) ]->{'content'};
	    $logger->info("Changing secret word to...".$ziggy_data->{'secret_word'}->{'word'});
	            
	}
	sub change_word_loop {
    	use vars qw ($ziggy_config_ref $ziggy_data);  #import $ziggy_config_ref to this scope
		$logger->debug("Inside change_word_loop");
		
		&change_secret_word( $ziggy_config_ref,$ziggy_data); 
	}



#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::SecretWord");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $secretword=$ziggy_data->{'secret_word'}->{'word'};
        # if someone says the secret word
    	$logger->debug("Can't be said until ".($ziggy_data->{'secret_word'}->{'interval'}+$ziggy_data->{'secret_word'}->{'last_said'})."");
    	$logger->debug("Right now it is     ".(time)."");
    	$logger->debug("Secret word is      $secretword");
        if ( ($msg =~ /\b$secretword\b/i)      and
                (! defined $ziggy_data->{'secret_word'}->{'last_said'} ||
                $ziggy_data->{'secret_word'}->{'last_said'} +$ziggy_data->{'secret_word'}->{'interval'}<time )   ){

            # set the last_eyeroll to NOW.
            $ziggy_data->{'secret_word'}->{'last_said'}=time;
            $logger->info("secret word was said!");

            
            $irc->_send_event(
                    'say' ,
                    $channel ,
                    'YOU SAID THE SECRET WORD "'.$secretword.'"!!!! AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHHHHHHHHHHHHHHHHHHHHHHH!!!!!!!!!!!!!!!',
                    int(rand (1))+1 );
    		$logger->debug("Secret word was     ".$ziggy_data->{'secret_word'}->{'word'});
           	&change_secret_word($ziggy_config_ref,$ziggy_data); 
    		$logger->debug("Secret word is      ".$ziggy_data->{'secret_word'}->{'word'});
            return PCI_EAT_PLUGIN;
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }


    sub S_msg {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::SecretWord");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
		my $nick = ( split /!/, $who )[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
		if( $msg =~/help/i ){
            if( $msg =~/help *secret *word/i ){
                $logger->info("help for secret word...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "secretword",1);
            }
            return PCI_EAT_NONE;
		}elsif($msg =~/changesecretword/i and authorized($ziggy_data, $who) ){
           	&change_secret_word($ziggy_config_ref,$ziggy_data);
        	$logger->info("Changed secret word. ");
        	$irc->_send_event( 'say' ,  $nick, "Secret word changed.",1);
			return PCI_EAT_PLUGIN;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::SecretWord");
        $irc->_send_event( 'say' ,  $target, "      SecretWord:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  <secret word>",1);
        $irc->_send_event( 'say' ,  $target, "            Delay:     I pick a secret word and if you say it, I'll scream real loud and pick a new one",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  /msg changesecretword (authorized users only)",1);
        $irc->_send_event( 'say' ,  $target, "            Comments:  Don't make me sing the PeeWee's Playhouse themesong...",1);
   } 
#-----------------------------------------------------------
    
}
1;







