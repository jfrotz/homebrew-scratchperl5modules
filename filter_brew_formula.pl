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
	    elsif  ($line =~ /desc/)
	    {
		$i += 1;
		push( @newlines, extract_dist_metadata( $tarball ) );
		next;
	    }
	    elsif  ($line =~ /def install/)
	    {
		push( @newlines, examine_dist( $tarball ) );
		last;
	    }
	    push( @newlines, $line );
	}
	
	if  (open( RB, ">$file" ))
	{
	    print RB join( "\n", @newlines );
	    close( RB );
	}
	else
	{
	    print "ERROR: Unable to re-write formula: $file: $!\n";
	}
    }
    else
    {
	print "ERROR: Unable to read formula: $file: $!\n";
    }
    return( @newlines );
}



#----------------------------------------------------------------------
sub	examine_dist
{
    my( $tarball )	= shift;
    my( @newlines );

    my( $opts )		= "tzvf";
    $opts		= "tjvf"	if  ($tarball =~ /.bz2/);
    my( $cmd )		= "tar $opts $tarball";
    
    my( @output )	= `$cmd`;
    my( $prefix )	= `brew --prefix`;
    chomp( $prefix );
    my( @parts )	= split( /\s+/, $output[0] );
    my( $class )	= pop( @parts );
    chomp( $class );
    chop( $class );			## Trailing slash
    push( @newlines,
	  "",
	);
    foreach my $line (@output)
    {
	if  ($line =~ /Makefile.PL/)
	{
	    push( @newlines, 
		  "  def install",
		  "    system, \"perl Makefile.PL\"",
		  "    system, \"make install PREFIX=$prefix\"",
		  "  end",
		  "  test do",
		  "    system, \"make test\"",
		  "  end",
		  "",
		);
	}
	if  ($line =~ /Build.PL/)
	{
	    push( @newlines, 
		  "  def install",
		  "    system, \"perl Build.PL\"",
		  "    system, \"perl Build\"",
		  "    system, \"perl Build install --destdir $prefix\"",
		  "  end",
		  "  test do",
		  "    system, \"perl Build test\"",
		  "  end",
		  "",
		);
	    push( @newlines, "    system, \"perl Buil.PL\"" );
	    push( @newlines, "    system, \"perl Build --destdir $prefix\"" );
	}
    }

    return( @newlines );    
}




#----------------------------------------------------------------------
sub	extract_dist_metadata
{
    my( $tarball )	= shift;
    my( $opts )		= "xOzf";
    $opts		= "xOjf"	if  ($tarball =~ /\.bz2/);
    my( $cmd )		= "tar $opts $tarball --wildcards \"*/META.yml\"";
    my( @lines )	= `$cmd`;
    my( @newlines );
    foreach my $line (@lines)
    {
	chomp( $line );
	if  ($line =~ /abstract: '(.+)'/)
	{
	    push( @newlines, "    desc \"$1\"" );
	}
	elsif  ($line =~ /homepage: (.+)/)
	{
	    push( @newlines, "    homepage \"$1\"" );
	}
    }
    return( @newlines );
}
