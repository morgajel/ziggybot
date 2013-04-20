#!/usr/bin/perl
# Password generating (and maybe more) module
# this module is made by shabbs, (C)2006 or whatever
# not sure what the legal stuff is, but he made it for ziggy, 
# For now this module generates a random password of a user defined length, or 8
# if one was not specified


package passgen ;
{
    my $ziggy_config_ref;
    my $ziggy_data;
	use Log::Log4perl qw(get_logger);
    use Data::Dumper;
    use POE::Component::IRC::Plugin qw( :ALL );
    use strict;
   
    #Common functions are located in the lib directory
    use Common qw( filter );

	my $logger = get_logger("Ziggy::Passgen");
    $logger->debug("loading passgen");


    #your plugin is an object- treat it as such. it'll be passed a dereferenced
    # ziggy_config_ref and ziggy_data- use them as you will, but the rule of thumb
    # is ziggy_config_ref is read only, ziggy_data is writable
    sub new {
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
		my $logger = get_logger("Ziggy::Passgen");
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
	    $ziggy_data->{'passgen'}={};
        $ziggy_data->{'passgen'}->{'accepted_chars'}= 'abcdefghijkmnpqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWXYZ<>?=!@#$%^&*()';
        my $self={};
        # instanciate any object-level variables here if needed
        $self->{version}="1.0";
        $self->{pass_len} = 8;
        return bless $self, $package;
    }

    # This is one of the special plugin functions. Here is where you'll state what actions 
    # to spy on. it's run whenever modules are loaded or reloaded.
    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Passgen");
        # all events that you want to listen for, do so here.
        # you can use USER or SERVER, tho I'm not sure the differences.

        $irc->plugin_register( $self, 'SERVER', qw(  public msg ) );
        # you can also use privmsg, kick, join, etc.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::Passgen");
        return 1;
    }

#-------------------------------------------------------------------------------------------
#FIXME add quit messages
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Passgen");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        if ( $msg =~ /^!(genpass|passgen)/i ){
        	my ($cmd, $p_len) = split / / , $msg;
        	$p_len = $self->{pass_len} if(!$p_len);
            my $delay=1;
            # logger() is another one of my special functions- it makes debugging easier. 
            # Put them in when you need timestamps, or to mark important events.
            $logger->info("Generating $p_len character password.");
                       
			my $generated = generate($p_len);

            $irc->_send_event( 'say', $nick, "Generated password: ".$generated, $delay );
            
            return PCI_EAT_PLUGIN;
            
        }else{
            return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
        }
    }


	sub generate {
      use vars qw ($ziggy_data);
	  my $length = shift;
		my $logger = get_logger("Ziggy::Passgen");

	  my $possible = $ziggy_data->{'passgen'}->{'accepted_chars'};
	  my $password;
	  
	  while ($length-- and $length <50)
	  {
		$password .= substr($possible, (int(rand(length($possible)))), 1);
	  }

	  return $password
	}

    sub S_msg{
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Passgen");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        my ($nick)= split /!/ , $who ;
        $logger->info("help for passgen...");
		if( $msg =~/help/i ){
            if( $msg =~/help *passgen/i ){
                $logger->info("help for passgen...");
                &help($ziggy_config_ref,$nick,$irc);
            }elsif($msg =~/help *$/){
                $irc->_send_event( 'say' ,  $nick, "passgen",1);
            }
            return PCI_EAT_NONE;
        }
        return PCI_EAT_NONE;
    }
    sub help {
        my ($ziggy_config_ref,$target,$irc,$ziggy_data)=@_;
		my $logger = get_logger("Ziggy::Passgen");
        $irc->_send_event( 'say' ,  $target, "      passgen:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:       say \"!genpass or !passgen\" followed by the length (less than 50) ",1);
        $irc->_send_event( 'say' ,  $target, "            Allowed Chars: ".$ziggy_data->{'passgen'}->{'accepted_chars'}."",1);
   } 
    
#-----------------------------------------------------------

    # Default handler for events that do not have a corresponding plugin method defined.
    # Whatever is registered as something we're supposed to listen to, and it doesn't have
    # it's own function, it gets picked up by this- be wary when using it.
    sub _default {
        # notice that _default returns an extra item- $event. $event does not need to be dereferenced.
        my( $self, $irc, $event, $who, $channel, $msg ) = @_;
		my $logger = get_logger("Ziggy::Passgen");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        my ($nick)= split /!/ , $who ;
                
        #print "Nick: $nick ; who: $who; channel: $channel; event: $event;\n"; 

        #$irc->yield( privmsg => $channel => "Hello, this is a sample module default message.");
         
        # Return an exit code
        return PCI_EAT_NONE;
    }

}
1;
