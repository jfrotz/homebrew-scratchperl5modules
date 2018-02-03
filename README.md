# homebrew-scratchbrewpi
Experiments creating Raspberry Pi based LinuxBrew tap for Perl modules.

# THEORY:
  - Traversing a Perl application and its dependency matrix can identify the Formulae which needs to be created in a third-party Tap.
  
  # Experiment
  This project attempts to solve the problem (at work) where client teams want code to be written for them, but they don't have the expertise or reliable environment configuration to succeed when a Perl application has a deep dependency matrix.
  The typical cpan / cpanm solutions don't work as these users don't have sudo rights to instal the correct RPMs and they get in trouble if they add additional yum repos.
  
  This is an attempt to see how Homebrew works, based on the great idea behind Linuxbrew.
  
  # STEPS
    - Create a github repo (because Homebrew wants one).
    - Create / initialize the tap.
    - Create a forumlae to be built from source for any given CPAN module based on trolling the CPAN dist and generating the requisite brew create URL.
    - Check in the formulae.
    - Try: brew install FORMULAE
    
    
    
