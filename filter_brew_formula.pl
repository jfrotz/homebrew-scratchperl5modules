#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

filter_brew_formula.pl

=head1	USAGE

export HOMEBREW_EDITOR="perl ./filter_brew_formula.pl"
brew create https://cpan.metacpan.org/authors/id/M/MA/MATTP/Test-WWW-Selenium-1.36.tar.gz --autotools --set-name perl-test-www-selenium --tap jfrotz/scratchperl5modules

=head1	DESCRIPTION

This filter transforms / fixes up the generated Homebrew Formula file that
was created by "brew create".

The Homebrew documentation is a little light on the correct sequence
of commands to call, so we use --autotools as a standardized format to
transform into the build and test steps expected by the specified CPAN
module.

We have to be slightly tricky since we bounce in and out of a
Linuxbrew environment.

Our invocation has access to a Linuxbrew "perl", while our runtime is
significantly restricted by the restricted Linuxbrew "brew create"
command.  We have to traverse the paths available to us at runtime
to find our Perl.

=cut

use strict;
use Data::Dumper;

main( @ARGV );
exit( 0 );





#----------------------------------------------------------------------
=pod

=head2 main( $file )

USAGE:

    main( @ARGV );
    exit( 0 );

DESCRIPTION:

This is the main entry point into this filter.

=cut

sub	main
{
    my( $module )	= shift;
    my( $file )		= shift;

    $file	= $module	if  ($file eq "");
    my( $cfg )		= 
    {
	module	=> $module,
	file	=> $file,				## The current module we're creating.
	tap	=> "jfrotz/scratchperl5modules",	## The tap we're writing into.
	count	=> 0,					## Number of dependencies we've found.
	debug	=> 0,
	filter	=> $0,
	cache	=> "$ENV{HOME}/.cache/Homebrew",
    };
    my( @parts )	= split( /\//, $cfg->{file} );
    $cfg->{formula}	= pop( @parts );

    if  ($cfg->{debug})
    {
	print "INVOKE: $cfg->{filter} $cfg->{file}\n";
    }

    find_cached_tarball( $cfg );
    transform_formula( $cfg );
    if  ($cfg->{debug})
    {
	print "--[Diagnostics]----------------------------------------------------------------------\n";
	print Dumper( $cfg );
	print "--[Audit]----------------------------------------------------------------------\n";
    }
}





#----------------------------------------------------------------------
=pod

=head2 find_cached_tarball( $cfg )

USAGE:

    find_cached_tarball( $cfg );

DESCRIPTION:

This method identifies the path where Linuxbrew "brew create"
downloaded the specified CPAN module URL.  Found in $ENV{HOME}/.cache
on my Raspberry Pi.

=cut

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
=pod

=head2	transform_formula()

USAGE:

    transform_formula( $cfg );

DESCRIPTION:

This method opens the Linuxbrew "brew create"d formula in our tap and
uses a finite state automata (FSA) to figure out how to generate
appropriate ruby so that Linuxbrew creates our (source) forumla.

=cut

sub	transform_formula
{
    my( $cfg )		= shift;
    my( @newlines );

    if (open( RB, $cfg->{file} ))
    {
	my( @lines )	= <RB>;
	close( RB );

	if  ($cfg->{debug})
	{
	    print "--[Original]----------------------------------------------------------------------\n";
	    print @lines;
	}

	my( $opts )	= "xOzf";
	$opts		= "xOjf"	if  ($cfg->{tarball} =~ /\.bz2/);
	my( $cmd )	= "tar $opts $cfg->{tarball} --wildcards \"*/META.yml\"";
	my( @yaml )	= `$cmd`;
	$cfg->{yaml}	= \@yaml;
	
	my( $state )	= "";
	for( my $i=0; $i < @lines; $i++ )
	{
	    my( $line )	= $lines[$i];
	    chomp( $line );
	    if  ($line =~ /^\s*\#/ && $state eq "")
	    {
		next;
	    }
	    elsif ($line =~ /(class .+)/)
	    {
		push( @newlines, $1 );
		next;
	    }
	    elsif  ($line =~ /desc/)
	    {
		$i++;
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
	    if  ($cfg->{debug})
	    {
		print "--[Generated]----------------------------------------------------------------------\n";
		print join( "\n", @newlines );
	    }
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
=pod

=head2	examine_dist()

USAGE:

    examine_dist( $cfg );

DESCRIPTION:

Invoked by our formula finite state automata, this method trolls
through the cached CPAN module tarball for the build step signature
required by our formula's "def install" and "test do" stanzas.

We delegate dependency identification to yet another finite state
automata.

=cut

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
    my( $state )	= "searching";
    foreach my $line (@output)
    {
	if  ($state eq "searching")
	{
	    my( @parts ) = split( /\//, $line );

	    next	if  (@parts > 3);		## subcomponent build

	    if  ($line =~ /Makefile.PL/)
	    {
		if  ($cfg->{debug})
		{
		    print "LINE: $line";
		}
		push( @newlines, 
		      "  def install",
		      "    system \"which\", \"perl\"",
		      "    system \"which\", \"gcc\"",
		      "    system \"which\", \"make\"",
		      "    system \"perl\", \"Makefile.PL\", \"PREFIX=\$HOMEBREW_FORMULA_PREFIX\"",
		      "    system \"make\", \"install\"",
		      "  end",
		      "  test do",
		      "    system \"which\", \"perl\"",
		      "    system \"which\", \"gcc\"",
		      "    system \"which\", \"make\"",
		      "    system \"perl\", \"Makefile.PL\", \"PREFIX=\$HOMEBREW_FORMULA_PREFIX\"",
		      "    system \"make\", \"test\"",
		      "  end",
		      "end",
		      "",
		    );
		$state = "found";
	    }
	    elsif  ($line =~ /Build.PL/)
	    {
		if  ($cfg->{debug})
		{
		    print "LINE: $line";
		}
		push( @newlines, 
		      "  def install",
		      "    system \"which\", \"perl\"",
		      "    system \"which\", \"gcc\"",
		      "    system \"which\", \"make\"",
		      "    system \"perl\", \"Build.PL\"",
		      "    system \"perl\", \"Build\"",
		      "    system \"perl\", \"Build\", \"install\", \"--destdir\", \"$prefix\"",
		      "  end",
		      "  test do",
		      "    system \"which\", \"perl\"",
		      "    system \"which\", \"gcc\"",
		      "    system \"which\", \"make\"",
		      "    system \"perl\", \"Build.PL\"",
		      "    system \"perl\", \"Build\"",
		      "    system \"perl\", \"Build\", \"test\"",
		      "  end",
		      "end",
		      "",
		    );
		$state = "found";
	    }
	}
    }
    return( @newlines );    
}





#----------------------------------------------------------------------
=pod

=head2	extract_dist_metadata()

USAGE:

    push( @newlines, examine_dist( $cfg ) );

DESCRIPTION:

We extract, cache and parse META.yml for abstract: and homepage: data
for our Linuxbrew formula.

=cut

sub	extract_dist_metadata
{
    my( $cfg )		= shift;
    my( @lines )	= @{ $cfg->{yaml} };
    $cfg->{abstract}	= "";
    $cfg->{homepage}	= "https://cpan.metacpan.org/";
    foreach my $line (@lines)
    {
	chomp( $line );
	if  ($line =~ /abstract: '(.+)'/)
	{
	    $cfg->{abstract}	= $1;
	}
	elsif  ($line =~ /homepage: (.+)/)
	{
	    $cfg->{homepage}	= $1;		## Replace the default page.
	}
    }
    my( @newlines );
    push( @newlines, "  desc \"$cfg->{abstract}\"" );
    push( @newlines, "  homepage \"$cfg->{homepage}\"" );
    return( @newlines );
}





#----------------------------------------------------------------------
=pod

=head2	exstract_dist_dependencies()

USAGE:

    push( @newlines, extract_dist_metadata( $cfg ) );

DESCRIPTION:

We parse through META.yml recognizing all /(.*requires):\s*$/
segments and from there each indented requirement.

We know that if "perl" is already Linuxbrew installed, that the
signature we will find for Perl Core will show up as "perl-perl", so
we pre-see it.

For each dependency we determine if we have to generate a Linuxbrew
"brew create" invocation, or if we already have one.

=cut

sub	extract_dist_dependencies
{
    my( $cfg )		= shift;
    my( @lines )	= @{ $cfg->{yaml} };
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
	    $dependency		= "=> :build"		if  ($class eq "build_requires");
	    $dependency		= "=> :build"		if  ($class eq "configure_requires");

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
=pod

=head2	emit_prerequisite_brew_create_commands()

USAGE:

    push( @newlines, emit_prerequisite_brew_create_commands( $cfg, $module, $dependency, $cfg->{seen} ) );

DESCRIPTION:

This finite state automata will zcat the CPAN
02packages.details.txt.gz file installed by the Linuxbrew "perl" cpan
command, found in $ENV{HOME}/.cpan/sources/modules on my Raspberry Pi.

Each found dependency does the zcat so that we are memory neutral on a
Raspberry Pi.  Otherwise, we might have just sucked it into memory in
@{ $cfg->{cpan} } for speed.

Diagnostics are commented out so that the Linuxbrew "brew create"
output is appropriately spartan.

Here we are deep inside the Linuxbrew "brew create" runtime so we
have to determine if our tap already has a formula (whether it has
been checked into git and pushed or not).  

We also determine if we have previously seen a prerequisite CPAN
module.  If not, we deposit an ephemeral invocation shell script which
will be chained by ./brew_a_cup.pl above us in the process tree.
Because ./brew_a_cup.pl will pick up and execute each invocation
script, we only generate one if one hasn't been generated by a
different process invocation.

We assume that $ENV{HOME}/.cpan and $ENV{HOME}/.cache exist.

We assume that $ENV{HOMEBREW_LIBRARY} is consistently structured
across different Linuxbrew deployments.

We only emit the 'depends_on "formula"' syntax to the calling FSA
if we have not already seen it in this run.

=cut

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
			    print CREATE "export HOMEBREW_EDITOR=\"perl $cfg->{filter}\"\n";
			    print CREATE "set -x\n";
			    print CREATE join( " ",
					       "brew create https://cpan.metacpan.org/authors/id/$package",
					       "--autotools",
					       "--set-name $formula",
					       "--tap $cfg->{tap}\n",
				);
			    print CREATE join( " ",
					       "brew install",
#					       "--verbose",
					       "--debug",
					       "--env=std",
					       "--ignore-dependencies",
					       "--build-bottle",
					       "$formula\n",
				);
			    print CREATE join( " ",
					       "brew bottle",
					       "--version",
#					       "--verbose",
					       "$formula\n",
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
		push( @newlines, "  depends_on \"$formula\" $dependency" );
		$seen->{$formula}	= 1;
	    }
	}
	return( @newlines );
    }
    return();
}
