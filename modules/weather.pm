#!/usr/bin/perl -w

package weather ;
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
    use Weather::Com::Finder;
    use strict;

    #Common functions are located in the lib directory
    use Common qw(filter );
    
	my $logger = get_logger("Ziggy::Weather");
    $logger->debug("loading weather");


    sub new {
        my ($package) = shift;
        ($ziggy_config_ref,$ziggy_data)=@_;
		my $logger = get_logger("Ziggy::Weather");
        $ziggy_config_ref=$$ziggy_config_ref;
        $ziggy_data=$$ziggy_data;
        my $self={};
        return bless $self, $package;
    }

    sub PCI_register {
        my ( $self, $irc ) = splice @_, 0, 2;
		my $logger = get_logger("Ziggy::Weather");
        $irc->plugin_register( $self, 'SERVER', qw( public msg) );
        # check for public messages.
        return 1;
    }

    # This is method is mandatory but we don't actually have anything to do.
    sub PCI_unregister {
		my $logger = get_logger("Ziggy::Weather");
        return 1;
    }
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
    sub S_public {
        use vars qw ($ziggy_config_ref $ziggy_data);
        my ($self,$irc,$who,$channel,$msg)=@_;
		my $logger = get_logger("Ziggy::Weather");
        $who=$$who; $msg=$$msg; $channel=$$$channel[0];
        #NOTE: who, msg and channel are all three double-referenced.
        #yes it's ugly, and the second line makes it sane.
        
        my ($nick)= split /!/ , $who ;
        my $botname=$ziggy_data->{'attempted_nick'}->{'nickname'};
        
        # if someone asks for the weather
        if  ($msg =~ /^!weather *(.*)$/i  ){
            my $zipcode=$1||'48309';
            $logger->info("weather was triggered");
            $logger->info("using zipcode $zipcode");	

            
			# you have to fill in your ids from weather.com here
			my $PartnerId  = '1024630533';
			my $LicenseKey = '1b9b99fd8b66aafd';
			
			my %weatherargs = (
                'partner_id' => $PartnerId,
			    'license'    => $LicenseKey,
			    'language'   => 'en',
                'units'      => 's',
                'cache'      => '/tmp/weather',
			);

			if ( ! -e '/tmp/weather' ){
				mkdir "/tmp/weather";
			}
			#TODO: have it create /tmp/weather and set proper permissions.	
			my $weather_finder = Weather::Com::Finder->new(%weatherargs);
			
			my @locations = $weather_finder->find($zipcode);
		    $logger->info(scalar(@locations)." locations found.");	
            if (!defined $locations[0]){
                $logger->info("weather.com dropped the ball.");
                $irc->_send_event(
                    'say' ,
                    $channel ,
                    &filter("Sorry, weather.com didn't understand that.", $nick,[$irc->channel_list($channel)],$botname ),
                    int(rand (1))+1
                    );  
            
            }
		    $logger->info(Dumper(@locations));	
            my $location_limit=3;
			foreach my $location (@locations) {
                my $temp=$location->current_conditions()->temperature();
                my $humidity=$location->current_conditions()->humidity();
                my $windchill=$location->current_conditions()->windchill();
                my $weatherstring="Weather for ".$location->name().": "
                                 ."Current Conditions are ".$location->current_conditions()->description().", "
                                 .$temp."F degrees";

                if ($temp >80 and $humidity>40){
                #HI= c1+c2T+c3R+c4TR+c5T^2+c6R^2+c7T^2R+c8TR^2+c9T^2R^2
                    my $HI=
                        -42.379 
                      +   2.04901523  *$temp 
                      +  10.1433127   *$humidity 
                      +  -0.22475541  *$temp*$humidity 
                      +  -6.83783     *(10**(-3))*($temp**2) 
                      +  -5.481717    *(10**(-2))*($humidity**2) 
                      +   1.22874     *(10**(-3))*($temp**2)*$humidity 
                      +   8.5282      *(10**(-4))*$temp*($humidity**2)
                      +  -1.99        *(10**(-6))*($temp**2)*($humidity**2);
                    $HI=int($HI*10)/10;
                    $weatherstring.=" with ".$humidity."% humidity and a heat index of ".$HI."F.";
                    
                }elsif ($temp>50){
                    $weatherstring.=" with ".$humidity."% humidity.";
                            
                }elsif($temp<40){
                    $weatherstring.=" with a windchill of ".$windchill."F." ;
                }
		        #$logger->info("results:".$weatherstring);	
                #$logger->info("say" ." ". $channel ." ". &filter($weatherstring, $nick,[$irc->channel_list($channel)],$botname ), ." ". int(rand (1))+1);
                $irc->_send_event(
                    'say' ,
                    $channel ,
                    &filter($weatherstring, $nick,[$irc->channel_list($channel)],$botname ),
                    int(rand (1))+1  
                    );
                $location_limit--;
                if ($location_limit<=0){
                    last;
                }
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
		my $logger = get_logger("Ziggy::Weather");
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
		my $logger = get_logger("Ziggy::Weather");
        $irc->_send_event( 'say' ,  $target, "      weather:",1);
        $irc->_send_event( 'say' ,  $target, "            Triggers:  say \"!weather [zipcode]\"",1);
        $irc->_send_event( 'say' ,  $target, "            Based on Weather::Com - fetching weather information from weather.com",1);
   } 

    
#-----------------------------------------------------------
}
1;







