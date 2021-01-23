#!/usr/bin/perl

use utf8;   
use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock);
use Encode;

#===============================================================================
#   lib_config_read():
#       Чтение конфигурационных директив из текстового файла
#===============================================================================
sub lib_config_read {
    my ( $hash_opt, $hash_in, $hash_out ) = @_;
    my $subname = 'lib_config_read';

    if ( not defined $hash_opt ) { return ( -1, $subname.': hash <hash_opt> is empty' ); }
    if ( not defined $hash_in ) { return ( -1, $subname.': hash <hash_in> is empty' ); }
    if ( not defined $hash_out ) { return ( -1, $subname.': hash <hash_out> is empty' ); }
    %{$hash_out} = ();

    if ( not defined $$hash_opt{'filename'} or $$hash_opt{'filename'} eq '' ) { return ( -1, $subname.': <hash_opt.filename> is empty' ); }
    my $fname = $$hash_opt{'filename'};
    my $charset = ( defined $$hash_opt{'charset'} ? $$hash_opt{'charset'} : 'utf8' );

    # Пытаемся открыть файл для чтения
    my $fh;
    if ( not sysopen( $fh, $fname, O_RDONLY ) ) {
        return ( -1, $subname.': internal error sysopen('.$fname.') ['.$!.']' );
    }

    # Имя секции по умолчанию
    my $section = '';
    my $numstr = 0;
    while ( my $line = <$fh> ) {
        chomp( $line );
        $line = decode( $charset, $line );
        $numstr++;
        $line =~ s/^\s+//g;
        $line =~ s/\s+$//g;
        if ( $line =~ /^\s*\#/ or $line=~/^$/ ) { next; }
        if ( $line =~ /^\[(.*)\]$/ ) {
            # Определена новая секция
            $section = lc( $1 );
            next;
        }
        if ( $section eq '' ) { next; }
        if ( not $line =~ /\=/ ) { $line .= ' ='; }
        $line =~ /^(.*?)=(.*)$/;
        my $param = $1;
        my $value = $2;
        if ( not defined $param or $param eq '' ) { next; }
        $value =~ s/^\s+//g;
        $param =~ s/\s+$//g;
        # Имя директивы приведем к нижнему регистру
        $param = lc( $param );
        $$hash_out{$section}{$param} = $value;
    }
    close( $fh );

    return ( 1, $subname.': ok' );
}

#===============================================================================
#   lib_config_write():
#       Запись конфигурационных директив в текстовой файл
#===============================================================================
sub lib_config_write {
    my ( $hash_opt, $hash_in, $hash_out ) = @_;
    my $subname = 'lib_config_write';

    if ( not defined $hash_opt ) { return ( -1, $subname.': hash <hash_opt> is empty' ); }
    if ( not defined $hash_in ) { return ( -1, $subname.': hash <hash_in> is empty' ); }
    if ( not defined $hash_out ) { return ( -1, $subname.': hash <hash_out> is empty' ); }
    %{$hash_out} = ();

    if ( not defined $$hash_opt{'filename'} or $$hash_opt{'filename'} eq '' ) { return ( -1, $subname.': <hash_opt.filename> is empty' ); }
    my $fname = $$hash_opt{'filename'};
    my $charset = ( defined $$hash_opt{'charset'} ? $$hash_opt{'charset'} : 'utf8' );

    # Пытаемся открыть файл для записи
    my $fh;
    if ( not sysopen( $fh, $fname, O_WRONLY | O_CREAT | O_TRUNC ) ) {
        return ( -1, $subname.': internal error sysopen('.$fname.') ['.$!.']' );
    }
    foreach my $section ( keys %{$hash_in} ) {
        $section =~ s/^\s+//g;
        $section =~ s/\s+$//g;
        $section = lc( $section );
        print $fh encode( $charset, "\n[".$section."]\n" );
        foreach my $directive ( keys %{$$hash_in{$section}} ) {
            $directive =~ s/^\s+//g;
            $directive =~ s/\s+$//g;
            $directive = lc( $directive );
            print $fh encode( $charset, $directive.' = '.$$hash_in{$section}{$directive}."\n" );
        }
    }
    close( $fh );

    return ( 1, $subname.': ok' );
}

#===============================================================================
 # Эта одинакая единичка - для возврата в программу значения ИСТИНА, когда она подключается perl-директивой require
1