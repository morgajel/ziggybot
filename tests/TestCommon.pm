#!/usr/bin/perl -wT
###############################################################################
#
package TestCommon;

use strict;
use warnings;
use Test::More;
use Common;

use Data::Dumper;
use XML::Simple;
use vars qw(@ISA @EXPORT_OK $VERSION $XS_VERSION $TESTING_PERL_ONLY);
require Exporter;

@ISA       = qw(Exporter);
@EXPORT_OK = qw( );



subtest 'test verify_email' => sub {

    ok(   Common::verify_email('foo@example.com'),  'working email' );
    ok( ! Common::verify_email('foo@examplecom'),   'missing period' );
    ok( ! Common::verify_email('foo@example@com'),  'too many @' );
    ok( ! Common::verify_email('@example.com'),     'no user' );
    ok( ! Common::verify_email('foo@'),             'no domain' );

    done_testing();
};


subtest 'test username_available' => sub {

    my $userlist={ 'user'=>{
                        'morg1'=>{'boo'=>'bar'},
                        'morg2'=>{'bar'=>'baz'},
                    }
                };
    ok( ! Common::username_available($userlist, 'morg1'),  "user exists");
    ok(   Common::username_available($userlist, 'badguy'), "user doesn't exists");

};


subtest 'test generate_passwd' => sub {

    like( Common::generate_passwd(), qr/^[a-zA-Z0-9\._\-\!\@\#\$\%\^\&]{6,10}$/,  "generate a password");
    like( Common::generate_passwd(), qr/^[a-zA-Z0-9\._\-\!\@\#\$\%\^\&]{6,10}$/,  "generate a password");
    like( Common::generate_passwd(), qr/^[a-zA-Z0-9\._\-\!\@\#\$\%\^\&]{6,10}$/,  "generate a password");
    like( Common::generate_passwd(), qr/^[a-zA-Z0-9\._\-\!\@\#\$\%\^\&]{6,10}$/,  "generate a password");
};


subtest 'test is_admin' => sub {

    my $userlist={ 'user'=>{
                        'morg1'=>{'admin'=>'1'},
                        'morg2'=>{'bar'=>'baz'},
                        'morg3'=>{'bun'=>'bobo'},
                    }
                };
    my $data={ 'authorized_users'=>{'bob'=>'bob','dole'=>'dole', 'foo'=>'morg12', 'morg1'=>'morg1', 'morg2'=>'morg2'}};

    ok(   Common::is_admin($userlist, $data, 'morg1'),  "user is admin");
    ok( ! Common::is_admin($userlist, $data, 'morg2'),  "user isn't admin");
    ok( ! Common::is_admin($userlist, $data, 'bob'),    "user isn't admin");

};


subtest 'test authorized' => sub {

    my $data={ 'authorized_users'=>{'bob'=>'bob','dole'=>'dole', 'foo'=>'morg12', 'morg1'=>'morg1', 'morg2'=>'morg2'}};

    ok(   Common::authorized( $data, 'morg1'),  "user is admin");
    ok( ! Common::authorized( $data, 'boba'),    "user isn't admin");

};



1;

