Introduction
============
This is a no-frills, minimal deployment script. It's written in shell script. The only requirement on the server side is git *(>= 1.7).*

Deployment is done by tagging a version and pushing this tag to a target branch on the web server. A git hook on the web server does a git checkout of the pushed commit and afterwards switches a symlinks to the newly checked out version.

This deployment script also offers activation of a maintenance page while deployment is running. This is optional.

Getting started
===============
**1. Prepare your git repository**

    * clone this repo.
    * cd into the git project that you want to deploy.
    * run the comsolit_deploy/src/prepare_project from this repo.
    * edit the created files in your repo under .deploy/
    * create folders in .deploy/ with names of the branches you want to push e.g. "dev" or "master"
    * make sure to set the [deploy].root setting in .deploy/config e.g. root = /srv/vhosts/website/target
    * if you don't use tags delete the tags config lines

**2. Prepare the server**

    * Make sure you can ssh to the server
    * run comsolit_deploy/src/initial_setup $SSHCONNECT_STRING $PATH_ON_SERVER
        - SSHCONNECT_STRING is what you'd use when connecting with ssh. (Edit your ~/.ssh/config to set a port other then 22, see man ssh_config.)
        - if this doesn't work, clone and checkout the comsolit_deploy Repository direct from github to a folder comsolit_deploy.git
    * add the webserver repo as a git remote: git remote add $NAME ssh://$SSHCONNECT_STRING/$PATH_ON_SERVER/project.git
    * add your hookscript "post-checkout" for example in .deploy/hooks/
    * make sure the hookscript is executable

**3. Prepare your server configuration for maintenance page (optional)**

   *  create an own host directory for maintenance page e.g.

    ::

          <Directory /srv/vhosts/website/target/dev/maintenance>
               AllowOverride all
               Require all granted
               Options -Indexes +FollowSymlinks
          </Directory>

   * add an alias and conditions to redirect to a route with your alias.

    ::

        <VirtualHost *:80>
            Alias /wartung /srv/vhosts/website/target/dev/maintenance
            RewriteEngine On
            RewriteCond %{REQUEST_URI} !^/wartung
            RewriteCond /srv/vhosts/website/target/dev/.maintenance -f
            RewriteRule ^/(.*) /wartung [L,R=307]**

            ServerAlias website.ch
            ServerName website.ch
            DocumentRoot /srv/vhosts/website/target/dev/current
            <Directory /srv/vhosts/website/target/dev/current>
                    AllowOverride all
                    Options -Indexes +FollowSymlinks
                    Require all granted
            </Directory>
        </VirtualHost>
