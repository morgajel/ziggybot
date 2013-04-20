#!/usr/bin/perl -w
# 
# The following is a list of shared functions available to plugins and the core script.
#
#
package Common ;
use base qw(Exporter);
use Exporter; 
use Data::Dumper;
use vars qw(@EXPORT_OK); 
@EXPORT_OK = qw(filter authorized is_admin send_email generate_passwd username_available verify_email);
use Log::Log4perl qw(get_logger);




sub filter {
    my ($saying, $target,$users,$bot)=@_;
	my $logger = get_logger("Ziggy::Common->filter");

    # The Natural filter I'm using has the following definitions:
    # anyname:      is a random name from anyone in the $users list
    # target:       is the join/part speaker or otherwise target.
    # nontarget:    is anyname - target
    # bot:          is the bot
    # nonbot:       is anyname - bot
    # others:       is anyname -target - bot
    #

    my $anyname=$users;
    my $nontarget =[ grep { $_ ne $target }  @$users];
    my $nonbot    =[ grep { $_ ne $bot }     @$users];
    my $others    =[ grep { $_ ne $bot } @$nontarget];
    push @$others, "somebody"; # in case only ziggy and the target are in the channel.
    #pick a random user from each of the 4 groups
    my $rand_anyname=@$anyname[int(rand(scalar(@$anyname)))];
    my $rand_nontarget=@$nontarget[int(rand(scalar(@$nontarget)))];
    my $rand_nonbot=@$nonbot[int(rand(scalar(@$nonbot)))];
    my $rand_others=@$others[int(rand(scalar(@$others)))];


    $saying=~s/\[anyname\]/$rand_anyname/g;
    $saying=~s/\[target\]/$target/g;
    $saying=~s/\[nontarget\]/$rand_nontarget/g;
    $saying=~s/\[bot\]/$bot/g;
    $saying=~s/\[nonbot\]/$rand_nonbot/g;
    $saying=~s/\[other\]/$rand_others/g;
    return $saying;
}


sub authorized {
    # this is used to determine if the current user has already
    # authorized- it's  very straight forward, I just threw it
    # in a function because it's used so often.
	my $logger = get_logger("Ziggy::Common->authorized");

    my ($ziggy_data, $who) = @_;
    foreach my $user ( keys  %{  $ziggy_data->{'authorized_users'} }  ) {
        return 1 if ( $user eq $who );
    }
    return 0;

}

# This method is garbage.
sub is_admin {
    #TODO use authorized
    my ($user_ref, $ziggy_data, $who)=@_;
	my $logger = get_logger("Ziggy::Common->is_admin");

    # checks to see if who is an admin.
    foreach my $user ( keys  %{  $ziggy_data->{'authorized_users'} }  ) {
        $logger->info("are you an admin? ");
        my $username=$ziggy_data->{'authorized_users'}->{$user};

        if ($user eq $who and $user_ref->{'user'}->{$username}->{'admin'}){
            return 1;
        }
    }
    return 0;

}




sub send_email {
    my ($user_ref,$username,$email)=@_;
    my $password=&generate_passwd();
	my $logger = get_logger("Ziggy::Common->send_email");

    my $message=<<EOF
Hi, you wanted an account, so here you go. You're not an admin or nothing, but 
this is better than a sharp stick in the eye.
username: $username
password: $password

You can log in by messaging me the following:
  identify $username $password
  
you can change your password by typeing the following after logging in:
  changepw username oldpassword newpassword newpassword
  
if you lose your password, the process is more in depth:
  reset $username
I'll send you an email with a verify code, which you message to me
  reset $username verifycode
I'll then send you a new password to your email address.

Don't email me back though, because morgajel deletes my mail:(
-Ziggy

EOF
;
    #FIXME THIS IS ALL HARDCODED! pull from his xml!
    my $msg = MIME::Lite->new(
        From     =>"Ziggy \"not a bot\" Swift <ziggyswift\@morgajel.com>" ,
        To       =>"$username <$email>",
        Subject  =>"ziggy's secret message",
        Data     =>"$message",
        );
    
    $user_ref->{'user'}->{$username}->{'pass'}=Digest::MD5::md5_hex($password);
    $user_ref->{'user'}->{$username}->{'email'}=$email;
#    &writeconfig($ziggy_config_ref);

        
    return $msg->send;


}


sub generate_passwd {
    #passwords must be 6-8 chars
	my $logger = get_logger("Ziggy::Common->generate_passwd");
    my $passwd="";
    my @chars=split '','abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ._-1234567890!@#$%^&';
    my $length=int(rand(5))+6;#6-10 characters
    while ($length>0){
        $passwd =$passwd.$chars[int(rand(scalar(@chars)))];
        $length--;
    }
    return $passwd;
}



sub username_available {
    my ($user_ref,$username)=@_;
	my $logger = get_logger("Ziggy::Common->username_available");

    if (exists $user_ref->{'user'}->{$username}){
     return 0; #FAIL, exists
    }
    return 1; # this username is available, and hence what we want.
}


sub verify_email {
    # an email address is valid if 
    my ($email)=@_;
	my $logger = get_logger("Ziggy::Common->verify_email");
    my $emailregex='[0-9a-z\_\-\.]+\@[0-9a-z\_\-\.]+\.[a-z]+'; 
    #a simple regex cause I'm a simple guy. this can be fine-tuned later
    if ($email=~ /$emailregex/i ){
        return 1; # close enough
    }
    #nope
    return 0;
}








1;

