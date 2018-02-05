# homebrew-scratchperl5modules
Experiments creating Raspberry Pi based LinuxBrew tap for Perl modules.  This is likely not real, but hopefully the model will give someone ideas or useful tools.  At the very least, it may provide sufficient information / documentation to solve someone else's problem.

# THEORY:
  - Traversing a Perl application and its dependency matrix can identify the Formulae which needs to be created in a third-party Tap.  (#YetAnotherCPAN)
  
# EXPERIMENT
This project attempts to solve the problem (at work) where client teams want code to be written for them, but they don't have the expertise or reliable environment configuration to succeed when a Perl application has a deep dependency matrix. The typical cpan / cpanm solutions don't work as these users don't have sudo rights to instal the correct RPMs and they get in trouble if they add additional yum repos.
  
This is an attempt to see how Homebrew works, based on the great idea behind Linuxbrew.

My work environment has rights (sudo; root) but I now have to push full binaries to arbitrary platforms.  Some of which use a perl which affects the engineering segments as their default perl, which I cannot use nor modify for my purposes.
  
# STEPS
  - Create / login to your github account.
  - Create a github repo (because Homebrew wants one).
  - Create / initialize the tap.
  - Create a forumlae to be built from source for any given CPAN module based on trolling the CPAN dist and generating the requisite brew create URL.
  - Create bottles from generated formulae.
  - Check in the formulae.
  - Try: brew install FORMULAE

# brew tap jfrotz/scratchperl5modules
  - Connect your brew installation to this third party tap.
  - Works.

# brew_a_cup.pl Test::WWW::Selenium
  - git clone https://github.com/jfrotz/homebrew-scratchperl5modules.git
  - cd; cp homebrew-scratchperl5modules/*.pl .
  - brew install perl
  - perl brew_a_cup.pl Test::WWW::Selenium

# Build recipe (so far)
  - brew create URL --autotools --set-name FORMULA --tap TAP
  - brew install --verbose --debug --env=std --ignore-dependencies --build-bottle FORMULA
  - brew bottle --version --verbose FORMULA

## Problems overcome
  - Why "perl Makefile.PL PREFIX=/home/linuxbrew/.linuxbrew" was wrong.  
    - brew install --interactive (env | grep Cellar) => HOMEBREW_FORMULA_PREFIX.

## Problems to overcome
  - Figure out why my Raspberry Pi won't build a bottle.
  - Learning just enough Ruby to add diagnostics to each piece of code during a brew bottle command runtime to figure out what isn't being said yet.
  - Figure out the bottling code.

## TODO
  - Submit a /home/linuxbrew/.linuxbrew/Homebrew/docs/Perl.md page with all of the options
    - perlbrew - While not Linuxbrew, this is a very reasonable package for doing self-contain perl.
    - linuxbrew + cpan - Let CPAN manage the build from source and dependency problem.  (Current brew recommendation and this works.)
    - linuxbrew + bottled-cpan - What I'm trying to do here which is pre-compile individual cpan modules for a given architecture and bottle it.
  - Determine how to solve this problem with https://scoops.sh

# RTFM
  - /home/linuxbrew/.linuxbrew/docs/
  - /home/linuxbrew/.linuxbrew/docs/Bottles.md
