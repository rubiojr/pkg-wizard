pkgwiz remote-build -- Build RPMS using a  pkg-wizard build-bot 
===============================================================

## SYNOPSIS

**pkg-wizard remote-build** builds/fetches source RPMS and sends them to a pkg-wizard build-bot.

You need to have a [build-bot][build-bot.html] running before using remote-build.

## USAGE

`$ pkgwiz remote-build`

--buildbot is required.

Usage: rpmwiz remote-build (options)

    -b, --buildbot URL               rpmwiz build-bot URL
    -p, --buildbot-port PORT         rpmwiz build-bot PORT (default 80)
    -s, --source SRC
    -t, --tmpdir TEMP                Directory for downloaded files to be put
    -h, --help                       Show this message


## EXAMPLES

1. Fetch _my-package-1.0.src.rpm_ from _http://myserver.com_ and send it to _my-build-bot-address_ build-bot for building.

   `pkgwiz remote-build -b my-build-bot-address http://myserver.com/my-package-1.0.src.rpm`

2. Fetch package spec and sources from git://github.com/user/my-package-repo, build the SRPM and send it to the build-bot

   `pkgwiz remote-build -b my-build-bot-address git://github.com/frameos/ruby-rpm`


## SEE ALSO

[INIT-ENV](init-env.html), [BUILD-BOT](build-bot.html), [CREATE-SRPM](create-srpm.html), [PKGWIZ](pkgwiz.html), [INSTALLING PKG-WIZARD](install.html)
