 pkgwiz build-bot -- Fedora's Mock Web Service 
==============================================

## SYNOPSIS

**pkg-wizard build-bot** is a simple web-service on top of [Mock](http://fedoraproject.org/wiki/Projects/Mock). Think of it as something in between Fedora's Mock and the complex [Koji](http://fedoraproject.org/wiki/Koji).

The main goals of pkg-wizard build-bot are:

* Be easy to install.

* Be well documented.

* Be simple to use.

If you have tried to install and use Koji before, you know the drill. Having said that, Koji is much more powerful and featureful than pkg-wizard's build-bot.

## FEATURES

Used in combination with pkg-wizard [remote-build](remote-build.html), you can:
  
* Send source RPMS to build-bot (RPM spec file and sources can be local or remote)
* Monitor the build process 
* Tag builds
* Create yum repos
* Rebuild failed builds
* Review build logs

## RUNNING A PKG-WIZARD BUILD-BOT

I assume that you have pkg-wizard already installed. Refer to [INSTALLING PKG-WIZARD](install.html) and [INIT-ENV](init-env.html) otherwise.

Starting a new build-bot for the first time:

1. Create a buildbot user

   `$ adduser buildbot`

2. Add the buildbot user to the mock group

   `$ gpasswd -a buildbot mock`

3. Change user ID to buildbot and change to the /home/buildbot directory

   `$ su buildbot`

   `$ cd /home/buildbot`

4. Start the build-bot

   `$ pkgwiz build-bot -m epel-5-x86_64 --daemonize --log-format web`

   This will start a build-bot listening in port 4567/tcp, using the mock profile from /etc/mock/epel-5-x86_64.cfg. From now on, the build-bot is ready to accept packages. Make sure the build-bot server firewall permits incoming traffic to port 4567/tcp.
   The build-bot server logs to build-bot.log file in the current working directory.

5. OPTIONAL (RHEL/Fedora only): enable pkgwiz-buildbot system service

   If you want to start the build-bot automatically every time the system boots, run the following command:

   `$ chkconfig pkgwiz-buildbot on`


Have a look at [pkgwiz](pkgwiz.html) [remote-build](remote-build.html) to learn how to send packages to the build-bot.

## USAGE

`$ pkgwiz build-bot`

Invalid mock profile.

Usage: pkgwiz build-bot (options)

        --daemonize
        --log-format FMT             Log format to use (web, cli)
        --log-server-port PORT       log server port (60001 default)
    -m, --mock-profile PROF
    -p, --port PORT
        --working-dir DIR
    -h, --help                       Show this message

## UNDERSTANDING BUILD-BOT DIRECTORY LAYOUT

When pkg-wizard build-bot is started for the first time, it will create a few directories in the current working directory.

**incoming**

**output**

**failed**

**snapshot**

**tags**

**workspace**

**archive**

## SEE ALSO

[PKGWIZ](pkgwiz.html), [INIT-ENV](init-env.html), [REMOTE-BUILD](remote-build.html), [INSTALLING PKG-WIZARD](install.html)
