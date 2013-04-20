#!/usr/bin/perl

package cueball ;
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
    
	my $logger = get_logger("Ziggy::Cueball");
    $logger->debug("loading cueball");


    sub new {
        my ($package) = shift;
		my $logger = get_logger("Ziggy::Cueball");
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Cueball");
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
		my $logger = get_logger("Ziggy::Cueball");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        # if someone asks a magic cueball question and there is no last_cueball or cueball was a while ago
        if ( ($msg =~ /^magic cueball, .*\?$/i) and
                (! defined $ziggy_data->{'last_cueball'} ||
                $ziggy_data->{'last_cueball'} +$ziggy_config_ref->{'cueball'}->{'interval'}<time )   ){

            # set the last_cueball to NOW.
            $ziggy_data->{'last_cueball'}=time;
            $logger->info("magic cueball was triggered");

            #grab all are phrases
	        my @cueball_phrases = @{ $ziggy_config_ref->{'cueball'}->{'reply'} };
    	    #pick one phrase object
            my $random_phrase = $cueball_phrases[ rand( scalar(@cueball_phrases) ) ]->{'content'};

            my $content=&filter($random_phrase,$nick,[$irc->channel_list($channel)],$botname );            
            my $wait=2+int(rand (2));
            $irc->delay([ privmsg =>  $channel => $content],$wait);
            
            # warning allow him to say "back off"
			$ziggy_data->{'cueball_warning'}=0;
            return PCI_EAT_PLUGIN;
        }elsif(($msg =~ /^magic cueball, .*\?$/i)
        and $ziggy_data->{'cueball_warning'} < $ziggy_config_ref->{'cueball'}->{'warning_count'}){
            # increment warning count; can I use ++ on a hash?
			$ziggy_data->{'cueball_warning'}=$ziggy_data->{'cueball_warning'} + 1;

            my $warning_text=$ziggy_config_ref->{'cueball'}->{'warning'};

            my $content=&filter($warning_text,$nick,[$irc->channel_list($channel)],$botname );            
            my $wait=2+int(rand (2));
            $irc->delay([ privmsg =>  $channel => $content],$wait);

            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }


    sub S_msg {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Cueball");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for cueball...");
		if( $msg =~/help/i ){
            if( $msg =~/help *cueball/i ){
                $logger->info("help for cueball...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->delay([ privmsg =>  $nick => "cueball"],1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::Cueball");
        $irc->delay([ privmsg =>  $target => "      Cueball:"],1);
        $irc->delay([ privmsg =>  $target => "            Triggers:  say \"magic cueball, blah blah blah?\""],1);
        $irc->delay([ privmsg =>  $target => "            Delay:     I only do it once every ".$ziggy_config_ref->{'cueball'}->{'interval'}." seconds"],1);
   } 
    
#-----------------------------------------------------------
}
1;







