#!/usr/bin/perl -w

package svn ;
{
# I've been comitted 73 times!
# I consist of x lines
# my config file has 997 lines in it.

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

    #WARNING! FIXME: this needs to implement Find::Bin won't work properly unless it's run manually from this directory!

    #Common functions are located in the lib directory
    use Common qw(filter );
    
	my $logger = get_logger("Ziggy::Svn");
    $logger->debug("loading svn");


    sub new {
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
		my $logger = get_logger("Ziggy::Svn");
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Svn");
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
		my $logger = get_logger("Ziggy::Svn");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        
        
#morgajel@p-nut ~/devel/ziggy $ svn info; echo $#
#Path: .
#URL: svn+ssh://morgajel.com/www/subversion/projects/perl/ziggy/trunk
#Repository Root: svn+ssh://morgajel.com/www/subversion/projects/perl/ziggy
#Repository UUID: 59f85f07-fbfd-0310-be0c-c1ff73fa4355
#Revision: 73
#Node Kind: directory
#Schedule: normal
#Last Changed Author: morgajel
#Last Changed Rev: 73
#Last Changed Date: 2006-07-18 14:38:52 -0400 (Tue, 18 Jul 2006)
#Properties Last Updated: 2006-06-23 13:41:35 -0400 (Fri, 23 Jun 2006)
#
#0
#morgajel@p-nut ~/devel/ziggy $ cd ../
#morgajel@p-nut ~/devel $ svn info; echo $#
#svn: '.' is not a working copy
        if ($msg=~/^!svn/){
	        my @change_info=`svn info`;
	        if (scalar(@change_info) >1){
	            my $revision=$change_info[4];
	            $revision=~s/[^:]*\:\ +(.*)/\1/;
                chomp $revision;
	            my $change_author=$change_info[7];
	            $change_author=~s/[^:]*\:\ +(.*)/\1/;
                chomp $change_author;
	            my $last_update=$change_info[9];
	            $last_update=~s/^[^:]*\:\ +(....\-..\-..) (..\:..\:..).*$/\2, on \1/;
                chomp $last_update;
	            my $commit_string='I\'ve been committed '.$revision.' times! Last time was by '.$change_author.' at '.$last_update.'.';
	            $irc->_send_event( 'say' ,  $channel, $commit_string,1);
	        }else{
	            $irc->_send_event( 'say' ,  $channel, "sorry, no subversion installed or I'm not in a repository.",1);
	        
	        }
	        
       #==============================     
            
            return PCI_EAT_PLUGIN;
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }

    sub S_msg{
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Svn");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for weather...");
		if( $msg =~/help/i ){
            if( $msg =~/help *weather/i ){
                $logger->info("help for weather...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "weather",1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help{
        my ($ziggy_config_ref,$target,$irc)=@_;
		my $logger = get_logger("Ziggy::Svn");
        $irc->_send_event( 'say' ,  $target, "      svn:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers: !svn",1);
        $irc->_send_event( 'say' ,  $target, "            Comments: shows when ziggy was last committed, and who did it",1);
   } 

    
#-----------------------------------------------------------
}
1;

