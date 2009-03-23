package Biber::Utils ;
use strict ;
use warnings ;
use Carp ;
use LaTeX::Decode ;
use Biber::Constants ;
use base 'Exporter' ;

=head1 NAME

Biber::Utils - Various utility subs used in Biber

=cut

=head1 VERSION

Version 0.4

=head1 SYNOPSIS

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ parsename terseinitials terseinitials_withdash makenameid
    makenameinitid cleanstring normalize_string latexescape array_minus
    getlabel remove_outer } ;

=head1 FUNCTIONS

=head2 parsename

    Given a name string, this function returns a hash with all parts of the name
    resolved according to the BibTeX conventions.

    parsename('John Doe') 
    returns: 
    { firstname => 'John',  
      lastname => 'Doe', 
      prefix => undef, 
      suffix => undef, 
      namestring => 'Doe, John',
      nameinitstring => 'Doe_J' }

    parsename('von Berlichingen zu Hornberg, Johann G{\"o}tz') 
    returns: 
    { firstname => 'Johann G{\"o}tz',  
      lastname => 'Berlichingen zu Hornberg', 
      prefix => 'von', 
      suffix => undef, 
      namestring => 'Berlichingen zu Hornberg, Johann Gotz',
      nameinitstring => 'Berlichingen_zu_Hornberg_JG' }
=cut

sub parsename {
    my ($namestr, $opts) = @_ ;
    my $usepre = $opts->{useprefix} || $CONFIG_DEFAULT{useprefix} ;

    my $lastname ;
    my $firstname ;
    my $prefix ;
    my $suffix ;
    my $nameinitstr ;
    
    #  Arabic last names could begin with diacritics like ʿ or ‘ (e.g. ʿAlī)
    my $diacritics = qr/[\x{2bf}\x{2018}]/; # more? 
    #  Arabic names may be prefixed with an article (e.g. al-Hasan, as-Saleh)
    my $articleprefix = qr/\p{Ll}{2}-/; # etc

    if ( $namestr =~ /^{.+}$/ ) 
    { 
        $namestr = remove_outer($namestr) ;
        $lastname = $namestr ;
    } 
    elsif ( $namestr =~ /[^\\],.+[^\\],/ )    # pre? Lastname, suffix, Firstname
    {
        ( $prefix, $lastname, $suffix, $firstname ) = $namestr =~
            m/^(
                \p{Ll}
                (?:\p{Ll}|\s)+
               )?
               \s*
               (
                [^,]+
               |
                {[^,]+}
               )
               ,
               \s+
               ([^,]+)
               ,
               \s+
               ([^,]+)
             $/x ;

        #$lastname =~ s/^{(.+)}$/$1/g ;
        #$firstname =~ s/^{(.+)}$/$1/g ;
        $prefix =~ s/\s+$// if $prefix ;
        $suffix =~ s/\s+$// ;
    }
    elsif ( $namestr =~ /[^\\],/ )   # <pre> Lastname, Firstname
    {
        ( $prefix, $lastname, $firstname ) = $namestr =~
            m/^(
                \p{Ll} # prefix starts with lowercase
                (?:\p{Ll}|\s)+ # e.g. van der
                \s+
               )?
               (
                $articleprefix?$diacritics?
                [^,]+
                |
                {[^,]+}
               ),
               \s+
               (
                [^,]+
                |
                {.+}
               )
               $/x ;

        #$lastname =~ s/^{(.+)}$/$1/g ;
        #$firstname =~ s/^{(.+)}$/$1/g ;
        $namestr =~ s/^$prefix// if ( $prefix && ! $usepre) ;
        $prefix =~ s/\s+$// if $prefix ;
    }
    elsif ( $namestr =~ /\s/ ) # Firstname pre? Lastname
    {
        ( $firstname, $prefix, $lastname ) =
          $namestr =~ /^(
                         {.+}
                        |
                         (?:\p{Lu}\p{Ll}+\s*)+
                        )
                        \s+
                        (
                         (?:\p{Ll}|\s)+
                        )?
                        (.+)
                        $/x ;

        #$lastname =~ s/^{(.+)}$/$1/ ;
        $firstname =~ s/\s+$// if $firstname ;

        #$firstname =~ s/^{(.+)}$/$1/ if $firstname ;
        $prefix =~ s/\s+$// if $prefix ;
        $namestr = "" ;
        $namestr = $prefix if $prefix ;
        $namestr .= $lastname ;
        $namestr .= ", " . $firstname if $firstname ;
    }
    else 
    {    # Name alone
        print "$namestr : E\n";
        $lastname = $namestr ;
    }

    #TODO? $namestr =~ s/[\p{P}\p{S}\p{C}]+//g ;
    ## remove punctuation, symbols, separator and control ???

    $nameinitstr = "" ;
    $nameinitstr .= substr( $prefix, 0, 1 ) . " " if ( $usepre and $prefix ) ;
    $nameinitstr .= $lastname ;
    $nameinitstr .= " " . terseinitials($suffix) 
        if $suffix ;
    $nameinitstr .= " " . terseinitials($firstname) 
        if $firstname ;
    $nameinitstr =~ s/\s+/_/g ;

    return {
            namestring     => $namestr,
            nameinitstring => $nameinitstr,
            lastname       => $lastname,
            firstname      => $firstname,
            prefix         => $prefix,
            suffix         => $suffix
           }
}

=head2 makenameid

Given an array of names (as hashes), this internal sub returns a long string
with the concatenation of all names.

=cut

sub makenameid {
    my @names = @_ ;
    my @namestrings ;
    foreach my $n (@names) {
        push @namestrings, $n->{namestring} ;
    }
    my $tmp = join " ", @namestrings ;
    return cleanstring($tmp) ;
}

=head2 makenameinitid

Similar to makenameid, with the first names converted to initials.

=cut

sub makenameinitid {
    my @names = @_ ;
    my @namestrings ;
    foreach my $n (@names) {
        push @namestrings, $n->{nameinitstring} ;
    }
    my $tmp = join " ", @namestrings ;
    return cleanstring($tmp) ;
}

=head2 normalize_string

Removes LaTeX macros, and all punctuation, symbols, separators and control characters.

=cut

sub normalize_string {
    my $str = shift ;
    $str =~ s/\\[A-Za-z]+//g ; # remove latex macros (assuming they have only ASCII letters)
    $str =~ s/[\p{P}\p{S}\p{C}]+//g ; ### remove punctuation, symbols, separator and control
    return $str ;
}

=head2 cleanstring

Like normalize_string, but also removes leading and trailing whitespace, and
substitutes whitespace with underscore.

=cut

sub cleanstring {
    my $str = shift ;
    $str =~ s/([^\\])~/$1 /g ; # Foo~Bar -> Foo Bar
    $str = normalize_string($str) ;
    $str =~ s/^\s+// ;
    $str =~ s/\s+$// ;
    $str =~ s/\s+/_/g ;
    return $str ;
}

=head2 latexescape

Escapes the LaTeX special characters { } & ^ _ $ and %

=cut

sub latexescape { 
	my $str = shift ;
	my @latexspecials = qw| { } & _ % | ; 
	foreach my $char (@latexspecials) {
		$str =~ s/^$char/\\$char/g ; 
		$str =~ s/([^\\])$char/$1\\$char/g ;
	} ;
    $str =~ s/\$/\\\$/g ;
    $str =~ s/\^/\\\^/g ;
	return $str
}

=head2 terseinitials

terseinitials($str) returns the contatenated initials of all the words in $str.
    terseinitials('Louis Pierre de la Ramée') => 'LPdlR'

=cut

sub terseinitials {
    my $str = shift ;
    $str = terseinitials_withdash($str) ;
    $str =~ s/[\s\p{Pd}]+//g ;
    return $str ;
}

=head2 terseinitials_withdash

Same as terseinitials but does not remove dashes:
    terseinitials('Louis-Pierre de la Ramée') => 'L-PdlR'

=cut

sub terseinitials_withdash {
    my $str = shift ;
	$str =~ s/\\[\p{L}]+\s*//g ;  # remove tex macros
    $str =~ s/^{(\p{L}).+}$/$1/g ;    # {Aaaa Bbbbb Ccccc} -> A
    $str =~ s/{\s+(\S+)\s+}//g ;  # Aaaaa{ de }Bbbb -> AaaaaBbbbb
	# remove arabic prefix: al-Khwarizmi -> K / aṣ-Ṣāliḥ -> Ṣ ʿAbd~al-Raḥmān -> A etc
    $str =~ s/\ba\p{Ll}-// ; 
    # get rid of Punctuation (except DashPunctuation), Symbol and Other characters
    $str =~ s/[\x{2bf}\x{2018}\p{Lm}\p{Po}\p{Pc}\p{Ps}\p{Pe}\p{S}\p{C}]+//g ; 
    $str =~ s/\B\p{L}//g ;
    return $str ;
}

=head2 array_minus

array_minus(\@a, \@b) returns all elements in @a that are not in @b

=cut

sub array_minus {
	my ($a, $b) = @_ ;
	my %countb = () ;
    foreach my $elem (@$b) { 
		$countb{$elem}++ 
	} ;
    my @result ;
    foreach my $elem (@$a) {
        push @result, $elem unless $countb{$elem}
    } ;
    return @result
}

=head2 getlabel
    
    Utility function to generate the labelalpha from the names of the author or editor

=cut

sub getlabel {
    my ($namesref, $dt, $alphaothers) = @_ ;
    my @names = @$namesref ;
    my $label = "";
    my @lastnames = map { normalize_string( $_->{lastname}, $dt ) } @names ;
    my $noofauth  = scalar @names ;
    if ( $noofauth > 3 ) {
        $label =
          substr( $lastnames[0], 0, 3 ) . $alphaothers ;
    }
    elsif ( $noofauth == 1 ) {
        $label = substr( $lastnames[0], 0, 3 ) ;
    }
    else {
        foreach my $n (@lastnames) {
            $n =~ s/\P{Lu}//g ;
            $label .= $n ;
        }
    }

    return $label
}

=head2 remove_outer
    
    Remove surrounding curly brackets:  
        '{string}' -> 'string'

=cut

sub remove_outer {
    my $str = shift ;
    $str =~ s/^{(.+)}$/$1/ ;
    return $str
}

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1 ;

# vim: set tabstop=4 shiftwidth=4: 
