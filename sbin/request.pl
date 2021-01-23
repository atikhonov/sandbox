#!/usr/bin/perl

use utf8;
use Fcntl;
use strict;
use warnings;
use DBI;
use CGI;

# ==============================================================================
# Описание программы:
#   По запросу взять данные из БД
# ==============================================================================
# (C) 2021 by Андрей Тихонов ( aka ti-an ) [ ti-an@mail.ru ]
# ------------------------------------------------------------------------------
my $cgi = CGI->new;

# Подключаем библиотеки
require '../lib/lib_config.pl';

# Парсируем аргумент адреса получателя
my $ADDRESS = $cgi->param('address');

# Для тестов заглушка
#$ADDRESS = 'twad@balayan.su';

if ( not defined $ADDRESS or $ADDRESS eq '' ) {
    print $cgi->header('text/html','400 Bad request');
    exit( 1 );
}

# Определим текущие параметры из файла конфигурации
our %CONFIG_COMMON = ();
{
    my $fname = '../etc/config.conf';
    my ( $res_code, $res_txt ) = lib_config_read( { filename => $fname }, {}, \%CONFIG_COMMON );
    if ( $res_code < 0 ) {
	    print $cgi->header('text/html','500 Internal error');
        exit( 1 );
    }
}

# Лимит вывода записей
my $ROWS_LIMIT = ( defined $CONFIG_COMMON{'general'}{'rows_limit'} ? $CONFIG_COMMON{'general'}{'rows_limit'} : 100 );

# Подключаемся к БД
my $dbh;
{
    foreach my $param ( qw/dsn prefix username password/ ) {
        if ( not defined $CONFIG_COMMON{'connection'}{$param} or $CONFIG_COMMON{'connection'}{$param} eq '' ) {
            print $cgi->header('text/html','500 Internal error');
            exit( 1 );
        }
    }
    eval {
        $dbh = DBI->connect( 'dbi:'.$CONFIG_COMMON{'connection'}{'dsn'}, $CONFIG_COMMON{'connection'}{'username'}, $CONFIG_COMMON{'connection'}{'password'}, { PrintError => 0, PrintWarn => 0 } );
    };
    if ( $@ or not defined $dbh ) {
        print $cgi->header('text/html','500 Internal error');
        exit( 1 );
    }
    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 1;
    $dbh->do( 'SET character_set_results = utf8' );
    $dbh->{'mysql_enable_utf8'} = 1;
}

# ------------------------------------------------------------------------------
# Запрос в БД на получение информации
# ------------------------------------------------------------------------------
# Делаем запрос в БД с ограничением вывода на одну запись больше, чем лимит.
my $cmd = "(SELECT created,int_id,str FROM ".$CONFIG_COMMON{'connection'}{'prefix'}.".message WHERE int_id IN (SELECT int_id FROM ".$CONFIG_COMMON{'connection'}{'prefix'}.".log WHERE log.address LIKE '".$ADDRESS."'))";
$cmd .= " UNION (SELECT created,int_id,str FROM ".$CONFIG_COMMON{'connection'}{'prefix'}.".log WHERE log.address LIKE '".$ADDRESS."') ORDER BY int_id,created LIMIT ".( $ROWS_LIMIT + 1 );
my $rows_num = 0;
my $sth;
eval {
    $sth = $dbh->prepare( $cmd );
    if ( not defined $sth ) { return; }
    my $rv = $sth->execute();
    if ( not defined $rv ) { return; }
};
if ( $@ ) { print $cgi->header('text/html','500 Internal error'); print $@; exit( 1 ); }

print $cgi->header();
while ( my $hash_ref = $sth->fetchrow_hashref ) {
    $rows_num++;
    if ( $rows_num <= $ROWS_LIMIT ) {
        print $$hash_ref{'created'}."\t".$$hash_ref{'str'}."<BR>\n";
    }
}
if ( $rows_num > $ROWS_LIMIT ) {
    print "<B>Actual number of entries is greater than limit. Not all records shown.</B>";
}

exit( 0 );

