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


## SEE ALSO

[PKGWIZ](pkgwiz.html), [REMOTE-BUILD](remote-build.html), [INSTALLING PKG-WIZARD](install.html)
