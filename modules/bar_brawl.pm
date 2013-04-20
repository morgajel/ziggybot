#!/usr/bin/perl
# bar_brawl Module
# Basic functionality of this module can be found in modules/sample.pm
# This will only cover brawl-based code


package bar_brawl ;
{
    my $ziggy_config_ref;
    my $ziggy_data;
	use Log::Log4perl qw(get_logger);
    use Data::Dumper;
    use POE::Component::IRC::Plugin qw( :ALL );
    use strict;

    #Common functions are located in the lib directory
    use Common qw(filter );



	my $logger = get_logger("Ziggy::BarBrawl");
    $logger->debug("loading bar brawl");


    sub new {
		my $logger = get_logger("Ziggy::BarBrawl");
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::BarBrawl");
        # This is where we list which events we want to listen to- 
        # Since the brawl module only replies to actions (specifically ziggy
        # being attacked), we only use ctcp_action
        $irc->plugin_register( $self, 'SERVER', qw( ctcp_action public msg) );
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::BarBrawl");
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
# This is the core of barbrawl, right here. 
    sub S_ctcp_action {
        use vars qw ($ziggy_config_ref $ziggy_data);
		my $logger = get_logger("Ziggy::BarBrawl");
        my ($self,$irc,$who,$channel,$msg)=@_;
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        
        #Interval is how long to wait between brawls, in seconds. I think it's at 36000 is about 10 hours.
        my $interval=$ziggy_config_ref->{'brawl'}->{'interval'};
        #the time (in seconds) the last brawl was executed. May be empty at first
        my $last_brawl=$ziggy_data->{'brawl'}->{'last_brawl'}||0 ;

        # This if statement looks for someone attacking ziggy. As you can see
        # you can punch, kick, stab or hit ziggy and as long as the action 
        # meets this regex, it it will pass the first part.
        # The second part check to see if you've ever brawl before, and if you have, if enough time
        # has passed since the last brawl.
        #
        $logger->info("last_brawl: $last_brawl  Interval: $interval  combined: ".($last_brawl+$interval) );
        $logger->info("time: ".time);
        if ( $msg =~ /(punches|stabs|kicks|hits) .*$botname/i  and
                (($last_brawl+$interval) < time) ) {
            $logger->info("executing bar brawl"); 
            $ziggy_data->{'brawl'}->{'warnings'}=0;
            # BAR BRAWWWWL!

            $irc->delay([ privmsg =>  $channel => $ziggy_config_ref->{'brawl'}->{'announce'} ],1);
            $logger->info("told $channel ".$ziggy_config_ref->{'brawl'}->{'announce'});


            #since we're about to brawl, lets set that last_brawl time.
            $ziggy_data->{'brawl'}->{'last_brawl'}=time;

            #lets pull all of our moves from the config file for easier visual parsing.
            my @moves=@{ $ziggy_config_ref->{'brawl'}->{'brawl_option'} };
             
            # we're gonna fight 4-7 rounds
            $ziggy_data->{'brawl'}->{'brawlcount'}=int( rand(4))+4;
            my $wait=0;

            $logger->info("brawlcount: ".$ziggy_data->{'brawl'}->{'brawlcount'});



            while ($ziggy_data->{'brawl'}->{'brawlcount'}> 0){

                $logger->info("brawling...".$ziggy_data->{'brawl'}->{'brawlcount'});

                $ziggy_data->{'brawl'}->{'brawlcount'}=$ziggy_data->{'brawl'}->{'brawlcount'}-1;
                # our action is a randomly chosen move from the array
                my $action=@moves[int(rand(scalar(@moves)))];
                # this while loop will bust through all of these brawl in a matter of milliseconds.
                # Because of this, we need to stagger the wait/delay times. each loop adds a delay to the 
                # delay before it- if you have 5 rounds that execute at time 1234567, and all the random delays turn out to be
                # 5 seconds, the first delay will be 5 seconds, the next 10, the next 15, the next 20, etc from the time of 1234567.
                # make sense?
                $wait=$wait + 3 + (int rand(4));
                my $content= &filter(  $action->{'content'}, $nick,[$irc->channel_list($channel)],$botname );
                #yes, this is ugly. I know.

                if ($action->{'type'}  eq "say" ){
                    $irc->delay([ privmsg =>  $channel => $content ],$wait);
                }else{
                    $irc->delay([ ctcp =>  $channel => "ACTION $content" ],$wait);
                }

                $logger->info("said to $channel $content in $wait seconds");

            }             
            # and here's our quit statement.
            my $content= &filter(  $ziggy_config_ref->{'brawl'}->{'end'} , $nick,[$irc->channel_list($channel)],$botname );
            $irc->delay([ privmsg =>  $channel => $content ],$wait+3);
            $logger->info("said to $channel $content in $wait seconds");
            

            # stop processing at this point; we've done our damage.
            return PCI_EAT_ALL; 
			# if someone hits and   (last brawl+interval)
         }elsif( 
		 		$msg =~ /(punches|stabs|kicks|hits) .*$botname/i  
				and ($last_brawl+$interval) > time 
				and $ziggy_data->{'brawl'}->{'warnings'} < 6  
				and $ziggy_data->{'brawl'}->{'brawlcount'}==0 ){
            $logger->info("skipping bar brawl for another".(($last_brawl+$interval) - time)." seconds..."  );
            # FIXME should abstract this out.
			# FIXME need to put 2 count thing in here
#            $logger->info(   $last_brawl+$interval                        );
#            $logger->info(   time                                         );
#            $logger->info(   $ziggy_data->{'brawl'}->{'warnings'}         );
#            $logger->info(   $ziggy_data->{'brawl'}->{'brawlcount'}       );
#            $irc->_send_event( 'say' ,  $channel , "ugh, no more fighting for a while...",2 );
#            $ziggy_data->{'brawl'}->{'warnings'}++;
			
		 }else{

#            $logger->info(   "do nothing in the bar brawl"                );
#            $logger->info(   $last_brawl+$interval                        );
#            $logger->info(   time                                         );
#            $logger->info(   $ziggy_data->{'brawl'}->{'warnings'}         );
#            $logger->info(   $ziggy_data->{'brawl'}->{'brawlcount'}       );
             #do nothing because people won't shut up.
         }
            $logger->info("Brawl done");
        return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
    }

    sub S_msg {
        use vars qw ($ziggy_config_ref $ziggy_data);
		my $logger = get_logger("Ziggy::BarBrawl");
        my ($self,$irc,$who,$channel,$msg)=@_;
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("we're in barbrawl help");
		if( $msg =~/help/i ){
            if( $msg =~/help *bar *brawl/i ){
                $logger->info("help for bar brawl...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->delay([ privmsg =>  $nick => "barbrawl" ],1);
            }
            $logger->info("we're leaving barbrawl help");
            return PCI_EAT_NONE ;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::BarBrawl");
        $logger->info("we're in barbrawl help's help!");
        $irc->delay([ privmsg =>  $target => "      Bar Brawl:"],1);
        $irc->delay([ privmsg =>  $target => "            Triggers: perform an action where you punches|stabs|kicks|hits me"],1);
        $irc->delay([ privmsg =>  $target => "            Delay:    I only do it once every ".$ziggy_config_ref->{'brawl'}->{'interval'}." seconds"],1);
         
   } 


}
1;
