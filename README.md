# Setup PHPUnit for Local Lightning

This is an updated version of gist [setup-phpunit.sh](https://gist.github.com/keesiemeijer/a888f3d9609478b310c2d952644891ba)

I converted it to a repository to more easily update it. I couldn't seem to `git push` to the gist.

Add using the following.

`curl -o setup-phpunit.sh https://raw.githubusercontent.com/afragen/setup-phpunit/lightning/setup-phpunit.sh`

`setup-phpunit.sh` is meant to reside in `/app` and be run from `/app/public` as `bash ../setup-phpunit.sh` or from `/app` as `bash setup-phpunit.sh`

Running the script will create a correct version of `wp-tests-config.php` for your installation.
