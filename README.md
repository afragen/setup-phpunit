# Setup PHPUnit for Local Lightning

This is an updated version of gist [setup-phpunit.sh](https://gist.github.com/keesiemeijer/a888f3d9609478b310c2d952644891ba)

I converted it to a repository to more easily update it. I couldn't seem to `git push` to the gist.

## Installation

If you use a Mac please install [Homebrew](https://brew.sh) using the following command.

`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`

Install the `setup-phpunit.sh` script using the following.

`curl -o setup-phpunit.sh https://raw.githubusercontent.com/afragen/setup-phpunit/master/setup-phpunit.sh`

## Usage

`setup-phpunit.sh` is meant to reside in `/app` and be run from `/app/public` as `bash ../setup-phpunit.sh` or from `/app` as `bash setup-phpunit.sh`

## What It Does

This is meant as a primary replacement for the `install-wp-tests.sh` script created from plugin scaffolding with `wp scaffold plugin-tests your_plugin`.

* Installs correct version of PHPUnit, with option to specify version.
* Installs specified version of WordPress and WordPress Test Suite, with option to specify version.
* Create a correct version of `wp-tests-config.php` for your installation.
* Creates a test database.
* Cleans up afterwards.
