# homebrew-scratchperl5modules
Experiments creating Raspberry Pi based LinuxBrew tap for Perl modules.  This is likely not real, but hopefully the model will give someone ideas or useful tools.

# THEORY:
  - Traversing a Perl application and its dependency matrix can identify the Formulae which needs to be created in a third-party Tap.
  
# EXPERIMENT
This project attempts to solve the problem (at work) where client teams want code to be written for them, but they don't have the expertise or reliable environment configuration to succeed when a Perl application has a deep dependency matrix. The typical cpan / cpanm solutions don't work as these users don't have sudo rights to instal the correct RPMs and they get in trouble if they add additional yum repos.
  
This is an attempt to see how Homebrew works, based on the great idea behind Linuxbrew.
  
# STEPS
  - Create / login to your github account.
  - Create a github repo (because Homebrew wants one).
  - Create / initialize the tap.
  - Create a forumlae to be built from source for any given CPAN module based on trolling the CPAN dist and generating the requisite brew create URL.
  - Check in the formulae.
  - Try: brew install FORMULAE

# brew tap jfrotz/scratchperl5modules
  - Connect your brew installation to this third party tap.
  - Works.

# brew_a_cup.pl Test::WWW::Selenium
  - git clone https://github.com/jfrotz/homebrew-scratchperl5modules.git
  - cp homebrew-scratchperl5modules/*.pl .
  - brew install perl
  - perl brew_a_cup.pl Test::WWW::Selenium

# TESTING
  - I think I've figured out the "brew audit" issues.  Need to test across a depdendcy tree.
  - Figure out how these commands flow into brew_a_cup.pl
    - brew audit --new-formula perl-test-www-selenium
    - brew install perl-test-www-selenium
    - brew test perl-test-www-selenium
