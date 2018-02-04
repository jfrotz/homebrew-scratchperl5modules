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
    my( $cfg )		= 
    {
	file	=> $file,				## The current module we're creating.
	tap	=> "jfrotz/scratchperl5modules",	## The tap we're writing into.
	count	=> 0,					## Number of dependencies we've found.
    };
    my( @parts )	= split( /\//, $cfg->{file} );
    $cfg->{formula}	= pop( @parts );
    $cfg->{cache}	= "$ENV{HOME}/.cache/Homebrew";
    $cfg->{filter}	= $0;				## Capture so that we can emit a HOMEBREW_EDITOR expansion.

    find_cached_tarball( $cfg );
    transform_formula( $cfg );
}





#----------------------------------------------------------------------
sub	find_cached_tarball
{
    my( $cfg )		= shift;
    my( $dir )		= $cfg->{cache};
    my( $formula )	= $cfg->{formula};
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
    $cfg->{tarball}	= $tarball;
}





#----------------------------------------------------------------------
sub	transform_formula
{
    my( $cfg )		= shift;
    my( @newlines );

    if (open( RB, $cfg->{file} ))
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
		push( @newlines, extract_dist_metadata( $cfg ) );
		next;
	    }
	    elsif  ($line =~ /def install/)
	    {
		push( @newlines, examine_dist( $cfg ) );
		last;
	    }
	    push( @newlines, $line );
	}
	
	if  (open( RB, ">$cfg->{file}" ))
	{
	    print RB join( "\n", @newlines );
	    close( RB );
	}
	else
	{
	    print "ERROR: Unable to re-write formula: $cfg->{file}: $!\n";
	}
    }
    else
    {
	print "ERROR: Unable to read formula: $cfg->{file}: $!\n";
    }
    return( @newlines );
}



#----------------------------------------------------------------------
sub	examine_dist
{
    my( $cfg )		= shift;
    my( @newlines );

    my( $opts )		= "tzvf";
    $opts		= "tjvf"	if  ($cfg->{tarball} =~ /.bz2/);
    my( $cmd )		= "tar $opts $cfg->{tarball}";
    
    my( @output )	= `$cmd`;
    my( $prefix )	= `brew --prefix`;
    chomp( $prefix );
    my( @parts )	= split( /\s+/, $output[0] );
    my( $class )	= pop( @parts );
    chomp( $class );
    chop( $class );			## Trailing slash
    push( @newlines,
	  "",
	  extract_dist_dependencies( $cfg ),
	  "",
	);
    foreach my $line (@output)
    {
	if  ($line =~ /Makefile.PL/)
	{
	    push( @newlines, 
		  "  def install",
		  "    system \"perl\", \"Makefile.PL --prefix $prefix\"",
		  "    system \"make\", \"install\"",
		  "  end",
		  "  test do",
		  "    system \"perl\", \"Makefile.PL --prefix $prefix\"",
		  "    system \"make\", \"test\"",
		  "  end",
		  "end",
		  "",
		);
	}
	if  ($line =~ /Build.PL/)
	{
	    push( @newlines, 
		  "  def install",
		  "    system \"perl\", \"Build.PL\"",
		  "    system \"perl\", \"Build\"",
		  "    system \"perl\", \"Build install --destdir $prefix\"",
		  "  end",
		  "  test do",
		  "    system \"perl\", \"Build.PL\"",
		  "    system \"perl\", \"Build\"",
		  "    system \"perl\", \"Build test\"",
		  "  end",
		  "end",
		  "",
		);
	}
    }
    return( @newlines );    
}





#----------------------------------------------------------------------
sub	extract_dist_metadata
{
    my( $cfg )		= shift;
    my( $opts )		= "xOzf";
    $opts		= "xOjf"	if  ($cfg->{tarball} =~ /\.bz2/);
    my( $cmd )		= "tar $opts $cfg->{tarball} --wildcards \"*/META.yml\"";
    my( @lines )	= `$cmd`;
    my( @newlines );
    foreach my $line (@lines)
    {
	chomp( $line );
	if  ($line =~ /abstract: '(.+)'/)
	{
	    push( @newlines, "  desc \"$1\"" );
	}
	elsif  ($line =~ /homepage: (.+)/)
	{
	    push( @newlines, "  homepage \"$1\"" );
	}
    }
    return( @newlines );
}





#----------------------------------------------------------------------
sub	extract_dist_dependencies
{
    my( $cfg )		= shift;
    my( $opts )		= "xOzf";
    $opts		= "xOjf"	if  ($cfg->{tarball} =~ /\.bz2/);
    my( $cmd )		= "tar $opts $cfg->{tarball} --wildcards \"*/META.yml\"";
    my( @lines )	= `$cmd`;
    $cfg->{seen}	=
    {
	"perl-perl"	=> 1,
    };
    my( @newlines );
    for( my $i=0; $i < @lines; $i++ )
    {
	my( $line )	= $lines[$i];
	chomp( $line );
	if  ($line =~ /(.*requires):\s*$/)
	{
	    my( $class )	= $1;
	    my( $dependency )	= "";
	    $dependency		= " => :build"		if  ($class eq "build_requires");
	    $dependency		= " => :build"		if  ($class eq "configure_requires");

	    $i++;
	    while( $lines[$i] =~ /^\s+(\S+?): /)
	    {
		my( $module )	= $1;
		push( @newlines, emit_prerequisite_brew_create_commands( $cfg, $module, $dependency, $cfg->{seen} ) );
		$i++;
	    }
	    next;
	}
    }
    return( @newlines );
}





#----------------------------------------------------------------------
sub	emit_prerequisite_brew_create_commands
{
    my( $cfg )		= shift;
    my( $module )	= shift;
    my( $dependency )	= shift;
    my( $seen )		= shift;
    
    if( -f "$ENV{HOME}/.cpan/sources/modules/02packages.details.txt.gz" )
    {
	my( $cmd )	= "zcat $ENV{HOME}/.cpan/sources/modules/02packages.details.txt.gz | grep $module";
#	print "EXEC: [$module]: $cmd\n";
	my( @modules )	= `$cmd`;
	my( @newlines );
	foreach my $dep (@modules)
	{
	    chomp( $dep );
	    
	    my( @parts )	= split( /\s+/, $dep );
	    my( $match )	= $parts[0];
	    
	    
	    next		unless( $module eq $match );
#	    print "* $dep\n";
	    
	    my( $package )	= pop( @parts );
	    @parts		= split( /\//, $package );
	    my( $name )		= pop( @parts );
	    @parts		= split( /\-/, $name );
	    pop( @parts );
	    my( $formula )	= lc( join( "-", "perl", @parts ) );
	    unless( exists( $seen->{$formula} ) )
	    {
		unless  (-f "$ENV{HOMEBREW_LIBRARY}/Tap/$cfg->{tap}/$formula.rb")
		{
		    unless( -f "$ENV{HOME}/.cache/$formula" )
		    {
			if (open( CREATE, ">$ENV{HOME}/.cache/$formula" ))
			{
			    print CREATE "export HOMEBREW_EDITOR=\"perl $cfg->{filer}\"\n";
			    print CREATE join( " ",
					       "brew create https://cpan.metacpan.org/authors/id/$package",
					       "--autotools",
					       "--set-name $formula",
					       "--tap $cfg->{tap}\n",
				);
			    close( CREATE );
			}
			else
			{
			    print "ERROR: Unable to create $ENV{HOME}/.cache/$formula: $!\n";
			}
			$cfg->{count}++;
		    }
		}
		push( @newlines, "  depends_on \"$formula\"\t$dependency" );
		$seen->{$formula}	= 1;
	    }
	}
	return( @newlines );
    }
    return();
}
