#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

cap_bottle.pl

=head1	USAGE

perl cap_bottle.pl $formula

=head1	DESCRIPTION

Parse the output of a "brew bottle $formula" line.
Rewrite the $formula file to include the new bottle information.

=head2 USE CASES

* No "bottle do" section exists. (ADD)
* "bottle do" section exists but sha256 does not for architecture. (REPLACE)
* "bottle do" section exists, sha256 exists for architecture but does not match. (REPLACE)
* "bottle do" section exists, sha256 exists for architecture and does match.  (NOP)
* Error: No available formula with name FOO (NOP)

=cut

use strict;
use Data::Dumper;

main( @ARGV );
exit( 0 );


#----------------------------------------------------------------------
=pod

=head2	main()

USAGE:

    main( $formula );
    exit( 0 );

DESCRIPTION:

This is the main entry point.  Run "brew bottle $formula".  Handle the
ADD, REPLACE and NOP use cases for the specified formula.

=cut

sub	main
{
    my( $formula )	= shift;
    my( $cfg )		= 
    {
	formula => $formula,
	shipper	=> "cp",
	location=> "www",
	verbose	=> 1,
    };
    bottle( $cfg );
}


#----------------------------------------------------------------------
=pod

=head2	bottle()

USAGE:

    bottle( $cfg );

DESCRIPTION:

Run "brew bottle $cfg->{formula}" and parse the output.  Recognize the
which usecase is to be processed.

=cut

sub	bottle
{
    my( $cfg )	= shift;
    my( $cmd )	= "brew bottle $cfg->{formula}";
    print "Capping bottle of $cfg->{formula}...\n";
    my( @lines )= `$cmd`;

    $cfg->{state}	= "tap";
    foreach my $line (@lines)
    {
	print "$cfg->{state}: $line"		if  ($cfg->{verbose});
	chomp( $line );
	if  ($line =~ /Error:/)
	{
	    $cfg->{usecase}	= "nop";
	    last;
	}
	elsif ($cfg->{state} eq "tap")
	{
	    if  ($line =~ /Determining (.+?)\/(.+?)\/(.+?) bottle rebuild.../)
	    {
		$cfg->{tap}	= "$1/$2";
		$cfg->{TAP}	= "$1/homebrew-$2";
		$cfg->{bottle}	= $3;
		if  ($cfg->{bottle} ne $cfg->{formula})
		{
		    print "Bottling failure: $cfg->{bottle} ne $cfg->{formula}\n";
		    last;
		}
		$cfg->{state} = "architecture";
	    }
	    else
	    {
		print "Unrecognizable output: $line\n";
		$cfg->{usecase}	= "nop";
		last;
	    }
	}
	elsif ($cfg->{state} eq "architecture")
	{
	    if  ($line =~ /Bottling (.+?.bottle.tar.gz).../)
	    {
		$cfg->{firstrun}		= $1;
		my( @parts )		= split( /\./, $cfg->{firstrun} );
		pop( @parts );		## gz
		pop( @parts );		## tar
		pop( @parts );		## bottle
		$cfg->{architecture}	= pop( @parts );
		$cfg->{state}		= "relocatable";
		next;
	    }
	}
	elsif  ($cfg->{state} eq "relocatable")
	{
	    $cfg->{state} = "bottled";
	    next;
	}
	elsif  ($cfg->{state} eq "bottled")
	{
	    $cfg->{bottled}	= $line;
	    $cfg->{state}	= "bottle do";
	    next;
	}
	elsif  ($cfg->{state} eq "bottle do")
	{
	    $cfg->{state}	= "cellar";
	    next;
	}
	elsif  ($cfg->{state} eq "cellar")
	{
	    $cfg->{cellar}	= $line;
	    $cfg->{state}	= "sha256";
	    next;
	}
	elsif  ($cfg->{state} eq "sha256")
	{
	    $cfg->{sha256}	= $line;
	    last;
	}
    }
    contemplate_formula( $cfg );
}



#----------------------------------------------------------------------
sub	contemplate_formula
{
    my( $cfg )		= shift;
    $cfg->{prefix}	= `brew --prefix`;
    chomp( $cfg->{prefix} );
    my( $file )		= "$cfg->{prefix}/Homebrew/Library/Taps/$cfg->{TAP}/$cfg->{formula}.rb";
    if  (open( FORMULA, $file ))
    {
	my( @lines ) = <FORMULA>;
	close( FORMULA );

	$cfg->{usecase}	= "add";
	my( @newlines );
	foreach my $line (@lines)
	{
	    print "$cfg->{usecase}: $line"	if  ($cfg->{verbose});
	    chomp( $line );
	    if  ($cfg->{usecase} eq "add")
	    {
		$cfg->{usecase}	= "replace"	if ($line =~ /bottle do/);
		if ($line =~ /def install/)
		{
		    push( @newlines,
			  "  bottle do",
			  $cfg->{cellar},
			  $cfg->{sha256},
			  "  end",
			  "",
			);
		}
		push( @newlines, $line );
		next;
	    }
	    elsif  ($cfg->{usecase} eq "replace")
	    {
		push( @newlines, $cfg->{cellar} );
		$cfg->{usecase} = "update";
	    }
	    if  ($cfg->{usecase} eq "update")
	    {
		if  ($line =~ /:$cfg->{architecture}/)
		{
		    if  ($line eq $cfg->{architecture})
		    {
			$cfg->{usecase}	= "nop";
			push( @newlines, $line );
			last;
		    }
		    else
		    {
			push( @newlines, $cfg->{sha256} );
			$cfg->{usecase}	= "package";
			next;
		    }
		}
	    }
	    if  ($cfg->{usecase} eq "package")
	    {
		push( @newlines, $line );
	    }
	}
	if  ($cfg->{usecase} ne "nop")
	{
	    if  ($cfg->{verbose})
	    {
		print "\n";
		print "----------------------------------------------------------------------\n";
		print join( "\n", @newlines );
	    }
	    if  (open( FORMULA, ">$file"))
	    {
		print FORMULA join( "\n", @newlines );
		close( FORMULA );
		print "\nBottled.\n";
	    }
	    else
	    {
		print "Unable to ship bottle $cfg->{formula}: $file: $!\n";
	    }
	    print "Shipping...\n";
	    my( $cmd )	= "$cfg->{shipper} $cfg->{firstrun} $cfg->{location}";
	    if  ($cfg->{verbose})
	    {
		print "$cmd\n";
		print `$cmd`;
		print "\n";
	    }
	    else
	    {
		`$cmd`;
	    }
	}
	else
	{
	    print "Bottle $cfg->{formula} has already shipped.\n";
	}
    }
    else
    {
	print "Unable to open bottle $cfg->{formula}: $file: $!\n";
    }
}
