#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

brew_a_cup.pl

=head1	USAGE

perl brew_a_cup.pl Test::WWW:Selenium

=head1	DESCRIPTION

This controller will "brew create" the passed CPAN module and all
dependencies in the our tap.

This implementation deliberately avoids the use of anything outside of
Perl Core so that the bootstrap problem is minimized.

=cut

use strict;
use Data::Dumper;

main( @ARGV );
exit( 0 );





#----------------------------------------------------------------------
=pod

=head2	main()

USAGE:

    main( @modules );
    exit( 0 );

DESCRIPTION:

This is the main entry point where we iterate across each passed CPAN
module reference and brew a first cup, then process all dependencies
until we exhause the chain for the passed modules.

=cut

sub	main
{
    my( @modules )	= @_;
    my( $cfg )		= 
    {
	tap	=> "jfrotz/scratchperl5modules",	## The tap we're writing into.
	filter	=> "./filter_brew_formula.pl",		## Invoked by Linuxbrew "brew create"
	count	=> 0,					## Number of dependencies we've found.
	cache	=> "$ENV{HOME}/.cache",
	cups	=> {},					## $cfg->{cups}->{$formula} = 0 when needing to be poured
	debug	=> 0,
    };
    
    rinse_cups( $cfg );					## Clean our environment while debugging.
    foreach my $module (@modules)
    {
	brew_first_cup( $cfg, $module );
    }
    while( more_cups( $cfg ) )
    {
	pour_next_cup( $cfg );
    }
}




#----------------------------------------------------------------------
=pod

=head2	brew_first_cup()

USAGE:

    brew_first_cup( $cfg, $module );

DESCRIPTION:

This method will pour_first_cup(), then "drink" it.

=cut

sub	brew_first_cup
{
    my( $cfg )		= shift;
    my( $module )	= shift;

    $cfg->{count}++;
    my( $formula )	= pour_first_cup( $cfg, $module );
    print "$cfg->{count}: Brewing a cup of $formula...\n";
    my( @output )	= `sh $cfg->{cache}/$formula`;
    print @output	if  ($cfg->{debug});
    $cfg->{cups}->{$formula}	= 1;
}





#----------------------------------------------------------------------
=pod

=head2	rinse_cups()

    rinse_cups( $cfg );

DESCRIPTION:

Throwaway code to ensure that each testing run generates things 
correctly.

=cut

sub	rinse_cups
{
    my( $cfg )	= shift;

    opendir( DIRP, $cfg->{cache} );
    my( @entries ) = sort( readdir( DIRP ) );
    closedir( DIRP );

    foreach my $entry (@entries)
    {
	if (-f "$cfg->{cache}/$entry" && $entry =~ /perl-/)
	{
	    unlink( "$cfg->{cache}/$entry" );
	}
    }

    `rm /home/pi/.cache/perl*`;
    `rm /home/pi/.cache/Homebrew/perl-*`;
    `rm /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/jfrotz/homebrew-scratchperl5modules/*.rb`;
}




#----------------------------------------------------------------------
=pod

=head2	more_cups()

USAGE:

    while( more_cups( $cfg ) ) { pour_next_cup( $cfg ); }

DESCRIPTION:

Iterate over the cups generated and determine if our last cup
generated more dependencies to traverse.

=cut

sub	more_cups
{
    my( $cfg )	= shift;

    opendir( DIRP, $cfg->{cache} );
    my( @entries ) = sort( readdir( DIRP ) );
    closedir( DIRP );

    my( $found )	= 0;
    foreach my $entry (@entries)
    {
	if (-f "$cfg->{cache}/$entry" && $entry =~ /perl-/)
	{
	    unless( exists( $cfg->{cups}->{$entry} ) )
	    {
		$cfg->{cups}->{$entry}	= 0;
		$found	= 1;
		print "Queuing $entry...\n"	if  ($cfg->{debug});
	    }
	}
    }
    return( $found );
}



#----------------------------------------------------------------------
=pod

=head2	pour_next_cup()

USAGE:

    while( more_cups( $cfg ) ) { pour_next_cup( $cfg ); }

DESCRIPTION:

Pour and drink the next cup.  We do not look inside our tap, we only
look inside $ENV{HOME}/.cache.

=cut

sub	pour_next_cup
{
    my( $cfg )	= shift;

    foreach my $formula (sort( keys( %{ $cfg->{cups} } ) ))
    {
	unless  ($cfg->{cups}->{$formula})
	{
	    $cfg->{count}++;
	    print "$cfg->{count}: Brewing a cup of $formula...\n";
	    my( @output )	= `sh $cfg->{cache}/$formula`;
	    print @output	if  ($cfg->{debug});
	    $cfg->{cups}->{$formula}	= 1;
	}
    }
}




#----------------------------------------------------------------------
=pod

=head2	pour_first_cup()

USAGE:

    pour_first_cup( $cfg, $module );

DESCRIPTION:

This finite state automata will zcat the CPAN
02packages.details.txt.gz file installed by the Linuxbrew "perl" cpan
command, found in $ENV{HOME}/.cpan/sources/modules on my Raspberry Pi.

We lifted this code from filter_brew_formula.pl so that our command
line argument is the canonical Perl module name and from there we
generate a standard cup in $ENV{HOME}/.cache.

We assume that $ENV{HOME}/.cpan and $ENV{HOME}/.cache exist.

We assume that $ENV{HOMEBREW_LIBRARY} is consistently structured
across different Linuxbrew deployments.

=cut

sub	pour_first_cup
{
    my( $cfg )		= shift;
    my( $module )	= shift;
    
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
	    my( $cup )		= "$ENV{HOME}/.cache/$formula";
	    unless( -f $cup )
	    {
		if (open( CREATE, ">$cup" ))
		{
		    print CREATE "export HOMEBREW_EDITOR=\"perl $cfg->{filter}\"\n";
		    print CREATE join( " ",
				       "brew create https://cpan.metacpan.org/authors/id/$package",
				       "--autotools",
				       "--set-name $formula",
				       "--tap $cfg->{tap}\n",
			);
		    close( CREATE );
		    $cfg->{cups}->{$formula}	= 0;
		    return( $formula );
		}
		else
		{
		    print "ERROR: Unable to create $ENV{HOME}/.cache/$formula: $!\n";
		}
	    }
	}
    }
}
