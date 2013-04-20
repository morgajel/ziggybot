#!/usr/bin/perl

package dnd ;
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
    
	my $logger = get_logger("Ziggy::DnD");
    $logger->debug("loading DnD");


    sub new {
        my ($package) = shift;
		my $logger = get_logger("Ziggy::DnD");
        ($ziggy_config_ref,$ziggy_data)=@_;
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::DnD");
        $irc->plugin_register( $self, 'SERVER', qw( public msg ) );
        # check for public messages.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::DnD");
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::DnD");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        # What kind of triggers will ziggy have?
        if ( $msg =~ /^$botname.? roll .*(\d) stat.*$/i    ){
            my $diecount=$1;
            $logger->info("dicecount is $diecount");
            if ($diecount>6 or $diecount<1){
                $diecount=6;
                $logger->info("crap, we reset that...");
            }
        
            my $phrase="Lets see, using 3 of 4d6, rerolling ones, we get:";
            for (my $i=0;$i<$diecount;$i++){
                $phrase.=" ".&roll_stat().",";
            }
            chop $phrase;
            
            $irc->_send_event(
                    'say' ,
                    $channel ,
                    &filter($phrase,$nick,[$irc->channel_list($channel)],$botname ),
                    2+int(rand (2)) );
                
            return PCI_EAT_PLUGIN;
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }



    sub roll_stat{
        # this will return a stat that meets the 4ds, reroll ones once, take the highest 3.
        # avert your eyes, this is an ugly hack.
        my @rolls= (  int(rand(6))+1  ,  int(rand(6))+1  ,  int(rand(6))+1 ,  int(rand(6))+1  ) ;
		my $logger = get_logger("Ziggy::DnD");
        $logger->info("4 orig stats are \n".Dumper(@rolls));
        my $total=0;
        my $lowest=100;
        for (my $i=0;$i<scalar(@rolls);$i++){
        
            if ($rolls[$i] == 1){
                $rolls[$i] = int(rand(6))+1;
                $logger->info('rerolled 1, replaced it with'.$rolls[$i]);
            }
            if ($rolls[$i] < $lowest){
                $lowest=$rolls[$i];
            }
            $total+=$rolls[$i];
            
        }
        $logger->info("all four total is $total, but we have to remove $lowest.");
        $total-=$lowest;
        $logger->info("FINAL RESULT: $total");
        return $total;
    }
 


    sub S_msg{
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::DnD");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        $logger->info("help for dnd...");
		if( $msg =~/help/i ){
            if( $msg =~/help *dnd *$/i ){
                $logger->info("help for DnD...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "dnd",1);
            }
            return PCI_EAT_NONE;
        }elsif ( $msg =~ /^.*roll .*(\d) stat.*$/i    ){
            my $diecount=$1;
            $logger->info("dicecount is $diecount");
            if ($diecount>6 or $diecount<1){
                $diecount=6;
                $logger->info("crap, we reset that...");
            }
        
            my $phrase="Lets see, using 3 of 4d6, rerolling ones, we get:";
            for (my $i=0;$i<$diecount;$i++){
                $phrase.=" ".&roll_stat().",";
            }
            chop $phrase;
            
            $irc->_send_event(
                    'say' ,
                    $nick ,
                    &filter($phrase,$nick,[$nick],$botname ),
                    2+int(rand (2)) );
                
            return PCI_EAT_PLUGIN;

        }

        
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::DnD");
        $irc->_send_event( 'say' ,  $target, "      DnD:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  say \"[bot], roll \\d stats\" or message him \"roll \\d stats\"",1);
        $irc->_send_event( 'say' ,  $target, "            Comments:  I only roll up to 6 stats, and will default to 6 stats ",1);
   } 
    
#-----------------------------------------------------------
}
1;







