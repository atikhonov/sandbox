#!/usr/bin/perl

use utf8;
use Fcntl;
use strict;
use warnings;
use DBI;

# ==============================================================================
# Описание программы:
#   Парсер файла логов exim и запись в БД
# ==============================================================================
# (C) 2021 by Андрей Тихонов ( aka ti-an ) [ ti-an@mail.ru ]
# ------------------------------------------------------------------------------

# Подключаем библиотеки
require '../lib/lib_config.pl';

# Парсируем аргументы
if ( not defined $ARGV[0] or $ARGV[0] eq '' ) {
    print 'Usage: '.$0." filename\n" ;
    exit( 1 );
}
# Полный путь к файлу логов
my $FILENAME_IN = $ARGV[0];

# Определим текущие параметры из файла конфигурации
our %CONFIG_COMMON = ();
{
    my $fname = '../etc/config.conf';
    my ( $res_code, $res_txt ) = lib_config_read( { filename => $fname }, {}, \%CONFIG_COMMON );
    if ( $res_code < 0 ) {
	    print '-ERR: internal error lib_config_read('.$fname.') ['.$res_txt."]\n";
        exit( 1 );
    }
}

# Подключаемся к БД
print 'Connect to db: ';
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
print "ok\n";

# ------------------------------------------------------------------------------
# Парсируем файл логов и пишем результат в БД
# ------------------------------------------------------------------------------
print 'Open source file '.$FILENAME_IN.': ';
my $fh;
if ( not open( $fh, $FILENAME_IN ) ) {
    print '-ERR: open('.$FILENAME_IN.') internal error ['.$!.']'."\n";
    exit( 1 );
}
print "ok\n";

# Из цикла лучше вынести объявления переменных - так быстрее будет
$| = 1;
print 'Write to db: ';
my ( $res_code, $res_txt );
my ( $dd, $dt, $str, $int_id, $flag, $email, $other, $id, $timestamp );
my ( $stat_all, $stat_message, $stat_log, $stat_skip ) = ( 0, 0, 0, 0 );
while ( <$fh> ) {
    chomp;
    $stat_all++;
    if ( not /^(\d{4}-\d\d-\d\d)\s+(\d\d:\d\d:\d\d)\s+((.+?)\s+(.+?)\s+(.+?)\s+(.*))$/ ) { $stat_skip++; next; }
    ( $dd, $dt, $str, $int_id, $flag, $email, $other ) = ( $1, $2, $3, $4, $5, $6, $7 );
    # Если в адресе отсутствует '@' - отбрасываем
    if ( $email !~ /\@/ ) { $stat_skip++; next; }
    # Отбросим угловые скобки от адреса, если есть
    $email =~ s/^\<(.*)\>$/$1/;
    $timestamp = $dd.' '.$dt;
    # Получим id удаленной стороны
    $id = '';
    if ( $other =~ /\s+id=([^\s]+)/ ) { $id = $1; }
    # Экранируем кавычки в строковых переменных
    $id =~ s/([\'\"])/\\$1/g;
    $int_id =~ s/([\'\"])/\\$1/g;
    $email =~ s/([\'\"])/\\$1/g;
    $str =~ s/([\'\"])/\\$1/g;

    # Запись в БД
    if ( $flag eq '<=' ) {
        # Запись в <message>
        ( $res_code, $res_txt ) = sql_write( { handler => $dbh, prefix => $CONFIG_COMMON{'connection'}{'prefix'}, table_name => 'message' }, { created => "'".$timestamp."'", id => "'".$id."'", int_id => "'".$int_id."'", str => "'".$str."'" } );
        $stat_message++;
    } else {
        # Запись в <log>
        ( $res_code, $res_txt ) = sql_write( { handler => $dbh, prefix => $CONFIG_COMMON{'connection'}{'prefix'}, table_name => 'log' }, { created => "'".$timestamp."'", int_id => "'".$int_id."'", str => "'".$str."'", address => "'".$email."'" } );
        $stat_log++;
    }
    if ( $res_code < 0 ) { print 'e'; } else { print 'o'; }
}
print "\nStatictics:\n";
print "\t all rows:       ".$stat_all."\n";
print "\t skip rows:      ".$stat_skip."\n";
print "\t <message> rows: ".$stat_message."\n";
print "\t <log> rows:     ".$stat_log."\n";
print "\nFinish\n";
close( $fh );
exit( 0 );

# ==============================================================================
# Запись в БД
# ==============================================================================
sub sql_write {
    my ( $hash_opt, $hash_in ) = @_;

    my $cmd = 'INSERT INTO '.$$hash_opt{'prefix'}.'.'.$$hash_opt{'table_name'}.' ';
    my ( $col, $val ) = ( '', '' );
    foreach my $field( keys %{$hash_in} ) {
        $col .= $field.',';
        $val .= $$hash_in{$field}.','
    }
    $col =~ s/\,$//;
    $val =~ s/\,$//;
    $cmd .= '('.$col.') VALUES ('.$val.')';
    my $sth;
    eval {
        $sth = $$hash_opt{'handler'}->prepare( $cmd );
        if ( not defined $sth ) { return; }
        my $rv = $sth->execute();
        if ( not defined $rv ) { return; }
    };
    if ( $@ ) { return( -1, $@ ); }

    return( 1, 'ok' );
}
