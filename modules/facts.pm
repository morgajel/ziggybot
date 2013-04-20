#!/usr/bin/perl

package facts ;
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
    $logger->debug("loading facts");


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
        my $logger = get_logger("Ziggy::Facts");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        
        # if someone asks for a random fact and there is no last_fact or fact was a while ago
        if ( ($msg =~ /^!fact$/i or $msg =~ /^$botname, .*fact.*$/i  ) and
                (! defined $ziggy_data->{'last_fact'} ||
                $ziggy_data->{'last_fact'} +$ziggy_config_ref->{'facts'}->{'interval'}<time )   ){

            # set the last_fact to NOW.
            $ziggy_data->{'last_fact'}=time;
            $logger->info("random fact was triggered");

            #grab all are phrases
            my @fact_phrases = @{ $ziggy_config_ref->{'facts'}->{'option'} };
            #pick one phrase object
            my $random_phrase = $fact_phrases[ rand( scalar(@fact_phrases) ) ]->{'content'};
            $logger->info("random fact is".$random_phrase);

            my $alert=$irc->delay( [ privmsg => $channel => filter($random_phrase,$nick,[$irc->channel_list($channel)],$botname )    ], 2+int(rand (2)) );

            # warning allow him to say "back off"
            $ziggy_data->{'fact_warning'}=0;
            return PCI_EAT_PLUGIN;
        }elsif(( $msg =~ /^!fact$/i or $msg =~ /^!$botname, .*fact.*$/i  )
        and $ziggy_data->{'fact_warning'} < $ziggy_config_ref->{'facts'}->{'warning_count'}){
            # increment warning count; can I use ++ on a hash?
            $ziggy_data->{'fact_warning'}=$ziggy_data->{'fact_warning'} + 1;

            my $warning_text=$ziggy_config_ref->{'facts'}->{'warning'};

            my $alert=$irc->delay( [ privmsg => $channel => filter($warning_text,$nick,[$irc->channel_list($channel)],$botname )    ], 2+int(rand (2)) );


            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }

    sub S_msg {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
        my $logger = get_logger("Ziggy::Facts");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for facts...");
        if( $msg =~/help/i ){
            if( $msg =~/help *facts/i ){
                $logger->info("help for facts...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                my $alert=$irc->delay( [ privmsg => $nick => "facts"   ], 1 );
            }
            
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
        my $logger = get_logger("Ziggy::Facts");
        $irc->delay([ privmsg =>  $target => "      Facts:"],1);
        $irc->delay([ privmsg =>  $target => "            Triggers:  say \"[bot], blah blah fact blah\""],1);
        $irc->delay([ privmsg =>  $target => "            Delay:     I only do it once every ".$ziggy_config_ref->{'facts'}->{'interval'}." seconds"],1);
        $irc->delay([ privmsg =>  $target => "            There are currently ".scalar( @{ $ziggy_config_ref->{'facts'}->{'option'} } )." facts in the database."],1);
   } 

    
#-----------------------------------------------------------
}
1;







