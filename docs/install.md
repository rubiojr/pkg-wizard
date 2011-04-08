pkg-wizard -- simple framework and tools to build and manage RPM packages
==========================================================================

## SYNOPSIS

**pkg-wizard** is both a ruby library to deal with common RPM tasks and set of commands to build and create RPM packages.

pkg-wizard installs [pkgwiz](pkgwiz.html), the command line tool used to manage and build RPMS/SRPMS.
## INSTALLATION

Follow these steps (as root):

1. Install dependencies

   `yum install rubygems make ruby-devel gcc gcc-c++`

2. Install pkg-wizard

   `gem install pkg-wizard`

3. Setup the environment

   `pkgwiz init-env`

   This will install all the required dependencies to use pkg-wizard tools.

## USAGE

If you are a packager interested in using pkg-wizard build tools, have a look at [pkgwiz](pkgwiz.html).

## SEE ALSO

[PKGWIZ](pkgwiz.html)
