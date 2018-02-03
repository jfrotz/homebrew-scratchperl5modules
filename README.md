# homebrew-scratchperl5modules
Experiments creating Raspberry Pi based LinuxBrew tap for Perl modules.  This is likely not real, but hopefully the model will give someone ideas.

# THEORY:
  - Traversing a Perl application and its dependency matrix can identify the Formulae which needs to be created in a third-party Tap.
  
# Experiment
This project attempts to solve the problem (at work) where client teams want code to be written for them, but they don't have the expertise or reliable environment configuration to succeed when a Perl application has a deep dependency matrix. The typical cpan / cpanm solutions don't work as these users don't have sudo rights to instal the correct RPMs and they get in trouble if they add additional yum repos.
  
This is an attempt to see how Homebrew works, based on the great idea behind Linuxbrew.
  
# STEPS
  - Create a github repo (because Homebrew wants one).
  - Create / initialize the tap.
  - Create a forumlae to be built from source for any given CPAN module based on trolling the CPAN dist and generating the requisite brew create URL.
  - Check in the formulae.
  - Try: brew install FORMULAE

# brew tap jfrotz/scratchperl5modules
- Connect your brew installation to this third party tap.
- Works.

## REQUIREMENTS:
  - Github account.
  - SSH keys (recommended)

# STEPS
  - export HOMEBREW_EDITOR=./filter_brew_formula.pl
  - brew create https://cpan.metacpan.org/authors/id/M/MA/MATTP/Test-WWW-Selenium-1.36.tar.gz --autotools --set-name perl-test-www-selenium --tap jfrotz/scratchperl5modules
  
# TODO
  - Build filter_brew_formula.pl
  - Read the ruby code on the passed path.
  - Rewrite it so that standard format (--autotools) is rewritten based on how the CPAN module tarball wants to be invoked (Makefile.PL, Build.PL, others).
  
