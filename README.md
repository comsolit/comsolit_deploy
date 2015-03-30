# Introduction

This is a no-frills, minimal deployment script. It's written in shell script
thus the only requirement on the server side is git (>= 1.7).

Deployment is done by tagging a version and pushing this tag to a target
branch on the web server. A git hook on the web server does a git checkout of
the pushed commit and afterwards switches a symlinks to the newly checked out
version.

# Getting Started

1. Prepare your git repository
  1. clone this repo
  2. cd into the git project that you want to deploy
  3. run the `src/prepare_project` from this repo
  4. edit the created files under `.deploy/`
  5. make sure to set the deploy.root setting in `.deploy/config`

2. Prepare the server
  1. Make sure you can ssh to the server
  2. run `src/initial_setup $SSHCONNECT_STRING $PATH_ON_SERVER`
     * SSHCONNECT_STRING is what you'd use when connecting with ssh.

       (Edit your `~/.ssh/config` to set a port other then 22, see man ssh_config.)
     * PATH_ON_SERVER is the same as the deploy.root setting in .deploy/config.

That's all. Now try to push anything in the dev branch:

```sh
git push $REMOTE $SOMETHING:dev
```

To push to the release branch you need to create an annotated tag:

```sh
git tag -a 0.1+rc0
git push --tags $REMOTE 0.1+rc0^0:release
```

Master only accepts version numbers without the '+rcX' suffix.

# TODO

* make it possible to use sudo to do the deployment
* make it configurable how many checkouts are kept
* provide a 'maintenance site' and scripts to turn it on or off
* package https://github.com/etsy/mod_realdoc for debian and use it
* make the script smarter so it doesn't need the deploy.root setting

# other deployment tools

## yadt-project from immobilienscout 24

* http://yadt-project.org
* many levels to big

## https://github.com/git-deploy/git-deploy

* booking.com
* perl
* seltsamer workflow, ausgehend von einem zentralen staging server

## giddyup

* https://github.com/mpalmer/giddyup web application deployment with "git push"
* (shell)

## EugeneKay

* https://github.com/EugeneKay/scripts/blob/master/bash/git-deploy-hook.sh
* some nice preliminary checks for binaries

## [git-deploy](https://github.com/anchor/git-deploy) by anchor

* shell, python

# glossary

*  [DTAP](http://en.wikipedia.org/wiki/Development,_testing,_acceptance_and_production)
   is short for Development, Testing, Acceptance and Production
