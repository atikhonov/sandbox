#!/usr/bin/perl

use utf8;
use Fcntl;
use strict;
use warnings;
use DBI;

# ==============================================================================
# Описание программы:
#   Создание таблиц <message> и <log> в существующей БД
# ==============================================================================
# (C) 2021 by Андрей Тихонов ( aka ti-an ) [ ti-an@mail.ru ]
# ------------------------------------------------------------------------------
print "Started...\n";

# Определим текущие параметры из файла конфигурации
require '../lib/lib_config.pl';

our %CONFIG_COMMON = ();
{
    my $fname = '../etc/config.conf';
    my ( $res_code, $res_txt ) = lib_config_read( { filename => $fname }, {}, \%CONFIG_COMMON );
    if ( $res_code < 0 ) {
	    print "-ERR: internal error lib_config_read(".$fname.") [".$res_txt."]\n";
        exit( 1 );
    }
}

# Подключаемся к БД
my $dbh;
{
    foreach my $param ( qw/dsn prefix username password/ ) {
        if ( not defined $CONFIG_COMMON{'connection'}{$param} or $CONFIG_COMMON{'connection'}{$param} eq '' ) {
            print '-ERR: configuration parameter <connection.'.$param."> not defined\n";
            exit( 1 );
        }
    }
    eval {
        $dbh = DBI->connect( 'dbi:'.$CONFIG_COMMON{'connection'}{'dsn'}, $CONFIG_COMMON{'connection'}{'username'}, $CONFIG_COMMON{'connection'}{'password'}, { PrintError => 0, PrintWarn => 0 } );
    };
    if ( $@ or not defined $dbh ) {
        print '-ERR: DBI::connect() internal error ['.( defined $DBI::errstr ? $DBI::errstr : $@ )."]\n";
        exit( 1 );
    }
    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 1;
    $dbh->do( 'SET character_set_results = utf8' );
    $dbh->{'mysql_enable_utf8'} = 1;
}

# Создаем таблицы
{
    foreach my $tbl_name ( keys %{$CONFIG_COMMON{'tables'}} ) {
        my $cmd = $CONFIG_COMMON{'tables'}{$tbl_name};
        my $sth;
        eval {
            $sth = $dbh->prepare( $cmd );
            if ( not defined $sth ) { return; }
            my $rv = $sth->execute();
            if ( not defined $rv ) { return; }
        };
        if ( $@ ) { print '-ERR: DBI::execute(tables) internal error ['.$@.'] ('.$cmd.")\n"; exit( 1 ); }
    }
}

# Создаем индексы
# Нельзя в DBI послать несколько команд через ';'
{
    foreach my $tbl_name ( keys %{$CONFIG_COMMON{'indexes'}} ) {
        my $cmd = $CONFIG_COMMON{'indexes'}{$tbl_name};
        my $sth;
        eval {
            $sth = $dbh->prepare( $cmd );
            if ( not defined $sth ) { return; }
            my $rv = $sth->execute();
            if ( not defined $rv ) { return; }
        };
        if ( $@ ) { print '-ERR: DBI::execute(indexes) internal error ['.$@.'] ('.$cmd.")\n"; exit( 1 ); }
    }
}


print "+OK: success\n";
exit( 0 );

