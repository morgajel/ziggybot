
my $peterman_count=0;
sub peterman{
        use vars qw ( $ziggy_config_ref $warning);
		my $logger = get_logger("Ziggy::Peterman");
        my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
		my $channel = $_[10];
        
        if ( $peterman_count % 5 == 0 ) {
            $kernel->post( $ZIGGY_CORE_ID, 'privmsg', $channel,
                "OH GOD NO, IT BUUUUURNS, IT BUUURNS" );
            $peterman_count++;
        }
        elsif ( $peterman_count % 5 == 3 ) {
            $kernel->post( $ZIGGY_CORE_ID, 'privmsg', $channel,
                "PLEASE MAKE IT STOOOOP..." );
            $peterman_count++;
        }else{
            $peterman_count++
        }
}
