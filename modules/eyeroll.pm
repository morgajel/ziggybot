#!/usr/bin/perl
#/me rolls his eyes
#
#12!

package eyeroll ;
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
    
	my $logger = get_logger("Ziggy::Eyeroll");
    $logger->debug("loading eyeroll");


    sub new {
        my ($package) = shift;
		my $logger = get_logger("Ziggy::Eyeroll");
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={'interval'=>'360','warning_count'=>1};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Eyeroll");
        $irc->plugin_register( $self, 'SERVER', qw( public msg ) );
        # check for public messages.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::Eyeroll");
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Eyeroll");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        # if someone says "love"
        if ( ($msg =~ /\blove\b/i)      and
                (! defined $ziggy_data->{'last_eyeroll'} ||
                $ziggy_data->{'last_eyeroll'} +$self->{'interval'}<time )   ){

            # set the last_eyeroll to NOW.
            $ziggy_data->{'last_eyeroll'}=time;
            $logger->info("eyeroll was triggered");

            
            $irc->_send_event(
                    'act' ,
                    $channel ,
                    'rolls his eyes...',
                    int(rand (1))+1 );
            $irc->_send_event(
                    'say' ,
                    $channel ,
                    'I got a '.int(rand(20)+1).'!',
                    int(rand(2))+2 );
            
            # warning allow him to say "back off"
			$ziggy_data->{'eyeroll_warning'}=0;
            return PCI_EAT_PLUGIN;
        }elsif(  ($msg =~ /\blove\b/i)
        and  $ziggy_data->{'eyeroll_warning'} < $self->{'warning_count'}){
            # increment warning count; can I use ++ on a hash?
			$ziggy_data->{'eyeroll_warning'}=$ziggy_data->{'eyeroll_warning'} + 1;


            $irc->_send_event(
                    'say' ,   
                    $channel ,
                    'ick.',
                    1+int(rand(2)) );


            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }


    sub S_msg{
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Eyeroll");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for eyeroll...");
		if( $msg =~/help/i ){
            if( $msg =~/help *eyeroll/i ){
                $logger->info("help for eyeroll...");
                &help($self,$ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "eyeroll",1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
		#TODO get rid of $self->interval in place of ziggy->config so I can remove $self
        my ($self,$ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::Eyeroll");
        $irc->_send_event( 'say' ,  $target, "      eyeroll:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  love",1);
        $irc->_send_event( 'say' ,  $target, "            Delay:     I only do it once every ".$self->{'interval'}." seconds",1);
        $irc->_send_event( 'say' ,  $target, "            Comments:  I don't like mushy stuff.",1);
   } 
    
#-----------------------------------------------------------
}
1;







