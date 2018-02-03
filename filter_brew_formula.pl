#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

filter_brew_formula.pl

=head1	USAGE

export HOMEBREW_EDITOR=./filter_brew_formula.pl
brew create https://cpan.metacpan.org/authors/id/M/MA/MATTP/Test-WWW-Selenium-1.36.tar.gz --autotools --set-name perl-test-www-selenium --tap jfrotz/scratchperl5modules

=head1	DESCRIPTION

This filter transforms / fixes up the generated Homebrew Formula file that
was created by "brew create".

We take some liberties with the configuration file in the way that we 
rewrite it.

=cut

use strict;
use Data::Dumper;

main( @ARGV );
exit( 0 );


#----------------------------------------------------------------------
sub	main
{
    my( $file )		= shift;
    my( @parts )	= split( /\//, $file );
    my( $formula )	= pop( @parts );
    my( $cache )	= "$ENV{HOME}/.cache/Homebrew";
    my( $tarball )	= find_cached_tarball( $cache, $formula );

    transform_formula( $file, $tarball );
#    unlink( $tarball );
}


#----------------------------------------------------------------------
sub	find_cached_tarball
{
    my( $dir )		= shift;
    my( $formula )	= shift;
    my( $tarball )	= "";

    $formula		=~ s/\.rb$//g;

    opendir( DIRP, $dir );
    my( @entries )	= sort( readdir( DIRP ) );
    closedir( DIRP );

    foreach my $entry (@entries)
    {
	if  (-f "$dir/$entry")
	{
	    if (index( $entry, $formula, 0 ) == 0)
	    {
		$tarball	= "$dir/$entry";
	    }
	}
    }
    return( $tarball );
}


#----------------------------------------------------------------------
sub	transform_formula
{
    my( $file )		= shift;
    my( $tarball )	= shift;
    my( @newlines );

    if (open( RB, $file ))
    {
	my( @lines )	= <RB>;
	close( RB );

	my( $state )	= "";
	for( my $i=0; $i < @lines; $i++ )
	{
	    my( $line )	= $lines[$i];
	    chomp( $line );
	    if  ($line =~ /^\s*\#/ && $state eq "")
	    {
		next;
	    }
	    elsif  ($line =~ /\.\/configure/)
	    {
		$i += 4;
		$state = "keep-comments";
		push( @newlines, "    # Crack open dist and interrogate build system." );
		push( @newlines, examine_dist_build( $tarball ) );
		next;
	    }
	    push( @newlines, $line );
	}
	
	print join( "\n", @newlines );
	unlink( $file );
    }
    else
    {
	print "ERROR: Unable to read formula: $file: $!\n";
    }
    return( @newlines );
}



#----------------------------------------------------------------------
sub	examine_dist_build
{
    my( $tarball )	= shift;
    my( @newlines );

    my( $opts )		= "tzvf";
    $opts		= "tjvf"	if  ($tarball =~ /.bz2/);
    my( $cmd )		= "tar $opts $tarball";
    
    print "EXEC: $cmd\n";
    my( @output )	= `$cmd`;
    print "OUTPUT:\n";
    print "----------------------------------------------------------------------\n";
    print @output;
    print "----------------------------------------------------------------------\n";

    my( $prefix )	= `brew --prefix`;
    foreach my $line (@output)
    {
	if  ($line =~ /Makefile.PL/)
	{
	    push( @newlines, "    system, \"perl Makefile.PL\"" );
	    push( @newlines, "    system, \"make install PREFIX=$prefix\"" );
	}
    }

    print join( "\n", @newlines );
    return( @newlines );    
}
