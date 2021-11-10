#!/usr/bin/env bash

# ===============================================================================
# Script to install PHPUnit in the Local 5.x by Flywheel Mac app
# Modified from Kees Meijer's fabulous gist, https://gist.github.com/keesiemeijer/a888f3d9609478b310c2d952644891ba
# These packages are installed
#
#     PHPUnit, curl wget, rsync, git, subversion and composer.
#
# WordPress is installed in the `/tmp/wordpress` directory for use by PHPUnit.
# The WordPress test suite is installed in the `/tmp/wordpress-tests-lib` directory.
#
# The WordPress and WP Test Suite paths are added to the ~/.bashrc file as environment
# variables $WP_CORE_DIR and $WP_TESTS_DIR.
#
# That way plugins can make use of them for unit testing. Plugins that have their
# tests scaffolded by WP-CLI also makes use of them. VVV also adds these enviroment
# variables to the ~/.bashrc file by default.
#
# You only have to run this script once. PHPUnit (and the other packages) are
# still available next time you ssh into your site.
# You must use `/usr/local/bin/phpunit` for your testing.
#
# To update WordPress and the WP Test Suite re-run this script.
# Use options to install specific versions for PHPUnit, WordPress or the WP_UnitTestCase.
#
# Note: This script doesn't install the packages globally in the Local by Flywheel app
# Packages are only installed for the site where you've run this script.
# ===============================================================================

# ===============================================================================
# Instructions
#
# 1 - Download this file (setup-phpunit.sh) inside your site's /app folder
# curl -o setup-phpunit.sh https://raw.githubusercontent.com/afragen/setup-phpunit/master/setup-phpunit.sh
#
# 2 - Right click your site in the Local App and click Open Site SSH
# A new terminal window will open
#
# 3 - Go to your site's /app folder:
# cd /app
#
# 4 - Run this script
# bash setup-phpunit.sh
#
# 5 - Reload the .bashrc file
# source ~/.bashrc
#
# 6 - Check if PHPUnit is installed
# phpunit --version
#
# ===============================================================================

# ===============================================================================
# Options
#
# Without options this script installs/updates PHPUnit, WordPress and the WP test suite.
#
# Install a specific PHPUnit version with the --phpunit-version option.
#
#     bash setup-phpunit.sh --phpunit-version=7
#
# Install a specific WordPress version with the --wp-version option. This option
# accepts a version number, 'latest', 'trunk' or 'nightly'. Default 'latest'
#
#     bash setup-phpunit.sh --wp-version=5.0
#
# Install a specific WordPress Test Suite with the --wp-ts-version option. This option
# accepts a version number, 'latest', 'trunk' or 'nightly'. Default 'latest'
#
#     bash setup-phpunit.sh --wp-ts-version=trunk
#
# Update all packages (wget, curl etc) installed by this script with the --update-packages option.
#
#     bash setup-phpunit.sh --update-packages
#
# Use the --help or -? option to see more information about this script.
#
#     bash setup-phpunit.sh --help
#
# ===============================================================================

# ===============================================================================
# Default PHPUnit version
#
# The default installed PHPUnit version is similar to versions used in
# WordPress travis.yaml file in trunk.
#
# See https://core.trac.wordpress.org/browser/trunk/.travis.yml#L64
#
# PHPUnit version 7 is installed for PHP version 7.1 and above
# PHPUnit version 5 is installed for PHP version 7.0
# PHPUnit version 4 for all other PHP versions
#
# See ticket https://core.trac.wordpress.org/ticket/39822
# See ticket https://core.trac.wordpress.org/ticket/43218
#
# Run the command with a version if you need to test with a specific PHPUnit version
#
# bash setup-phpunit.sh --phpunit-version=7
#
# This example will install the latest PHPUnit from version 7 (e.g. 7.5.3)
#
# Available PHPUnit versions can be found here.
# https://phar.phpunit.de
#
# PHPUnit versions compatible with PHP versions can be found here.
# https://phpunit.de/supported-versions.html
#
# ===============================================================================

# Strings used in error messages.
readonly QUIT="Stopping script..."
readonly CONNECTION="Make sure you're connected to the internet."
readonly RED='\033[0;31m' # Red color.
readonly RESET='\033[0m'  # No color.

# /app/public dir for Local installation.
DIR=$(pwd)
BASE_DIR=$(echo $DIR | grep -o "app.*$")
if [[ "app/public" == $BASE_DIR ]]; then
	readonly LOCAL_PUBLIC=$DIR
elif [[ "app" == $BASE_DIR ]]; then
	readonly LOCAL_PUBLIC=$DIR/public
fi

# Functions
function download() {
	download=false
	if wget --spider "$1" >/dev/null 2>&1; then
		wget -q --show-progress -O "$2" "$1" && download=true

		# Check if file exists.
		if [[ -f "$2" && "$download" == true ]]; then
			return 0
		fi
	fi

	printf "${RED}WARNING${RESET} Could not download %s %s\n" "$1" "$CONNECTION"
	return 1
}

function download_test_suite() {
	local exit=0
	if wget --spider "https://develop.svn.wordpress.org/$1/tests/phpunit/includes/" >/dev/null 2>&1; then
		svn export --quiet --force "https://develop.svn.wordpress.org/$1/tests/phpunit/includes/" "/tmp/tmp-wordpress-tests-lib/includes/"
		svn export --quiet --force "https://develop.svn.wordpress.org/$1/tests/phpunit/data/" "/tmp/tmp-wordpress-tests-lib/data/"
		svn export --quiet --force "https://develop.svn.wordpress.org/$1/wp-tests-config-sample.php" "/tmp/tmp-wordpress-tests-lib/wp-tests-config.php"
		for path in includes data wp-tests-config.php; do
			# Check if path exists.
			[[ ! -e "/tmp/tmp-wordpress-tests-lib/$path" ]] && exit=1
		done
		if [[ 0 == "$exit" ]]; then
			return 0
		fi
	fi

	printf "${RED}WARNING${RESET} Could not download %s Test Suite. %s\n" "$2" "$CONNECTION"
	return 1
}

function packages_installed() {
	for file in wget curl svn rsync composer git; do
		bin=$(which $file)
		# Check if executable file.
		if ! [[ -f "$bin" && -x "$bin" ]]; then
			return 1
		fi
	done
	return 0
}

function clean_up_temp_files() {
	# Clean up files added by this script.
	[[ -d "/tmp/tmp-wordpress/" ]] && rm -rf "/tmp/tmp-wordpress/"
	[[ -d "/tmp/tmp-wordpress-tests-lib/" ]] && rm -rf "/tmp/tmp-wordpress-tests-lib/"
	[[ -f "/tmp/my.cnf" ]] && rm -f "/tmp/my.cnf"
}

function exit_script() {
	clean_up_temp_files
	exit 1
}

# Get arguments.
for arg in "$@"; do
	if [[ "$arg" =~ ^- ]]; then
		# Argument start with a dash.
		case "$arg" in
		--phpunit-version=*) PHPUNIT_VERSION=${arg#"--phpunit-version="} ;;
		--wp-version=*) WP_VERSION=${arg#"--wp-version="} ;;
		--wp-ts-version=*) WP_TS_VERSION=${arg#"--wp-ts-version="} ;;
		--update-packages*) UPDATE_PACKAGES=true ;;
		-? | --help)
			printf "Install PHPUnit in the Local by Flywheel Mac app\n\n"
			printf "Usage:\n"
			printf "\tbash setup-phpunit.sh [option...]\n\n"
			printf "Example:\n"
			printf "\tbash setup-phpunit.sh --phpunit-version=6 --wp-version=trunk\n\n"
			printf "Options:\n"
			printf -- "\t--phpunit-version    PHPUnit version to install\n"
			printf -- "\t--wp-version         WordPress version to install\n"
			printf -- "\t                     Accepts a version number, 'latest', 'trunk' or 'nightly'. Default 'latest'\n"
			printf -- "\t--wp-ts-version      WordPress Test Suite version to install\n"
			printf -- "\t                     Accepts a version number, 'latest', 'trunk' or 'nightly'. Default --wp-version option\n"
			printf -- "\t--update-packages    Update all packages installed by this script\n"
			printf -- "\t                     Updates curl wget, rsync, git, subversion and composer\n"
			printf -- "\t-?|--help            Display information about this script\n\n"
			exit 0
			;;
		*)
			printf "Unknown option: %s.\nUse \"bash setup-phpunit.sh --help\" to see all options\n%s\n" "$arg" "$QUIT_MSG"
			exit_script
			;;
		esac
	else
		# Argument doesn't start with a dash.
		printf "Unknown option: %s.\nUse \"bash setup-phpunit.sh --help\" to see all options\n%s\n" "$arg" "$QUIT_MSG"
		exit_script
	fi
done

# Can use $(uname) to determine OS type.
if [[ 'Darwin' == $(uname) ]]; then
	OS_TYPE="MacOS"
	BREW_PATH=$(brew --prefix)
else
	OS_TYPE="Linux/WSL"
fi
echo $OS_TYPE
INSTALL_PACKAGES=false
if ! packages_installed; then INSTALL_PACKAGES=true; fi
[[ -z "$UPDATE_PACKAGES" ]] && UPDATE_PACKAGES=false

if [[ "$INSTALL_PACKAGES" == true || "$UPDATE_PACKAGES" == true ]]; then

	[[ "$INSTALL_PACKAGES" == true ]] && printf "Installing packages...\n" || printf "Updating packages...\n"

	if [[ "MacOS" == $OS_TYPE && "$INSTALL_PACKAGES" == true ]]; then
		xcode-select --install
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
		brew install wget
		brew install svn
		# Composer installed in Local's Site Shell.
		# brew install composer
	fi
	if ! [[ "MacOS" == $OS_TYPE ]]; then
		# Re-synchronize the package index files from their sources.
		apt-get update -y

		# Install packages.
		apt-get install -y wget subversion curl git rsync

		# Install composer.
		if [[ -f "/usr/bin/curl" && ! -f "/usr/local/bin/composer" ]]; then
			curl -sS https://getcomposer.org/installer | php
			mv composer.phar /usr/local/bin/composer || exit
			if [[ -f "$HOME/.bashrc" ]]; then
				printf "Adding .composer/vendor/bin to the PATH\n"
				echo 'export PATH="$PATH:$HOME/.composer/vendor/bin"' >>"$HOME/.bashrc"
			fi
		else
			if [[ -f "/usr/local/bin/composer" ]]; then
				printf "Updating composer...\n"
				composer self-update || printf "${RED}WARNING${RESET} Could not update 	composer. %s\n" "$CONNECTION"
			fi
		fi
	fi
fi

# Re-check if all packages are installed.
if ! packages_installed; then
	printf "${RED}ERROR${RESET} Missing packages. %s\n%s\n" "$CONNECTION" "$QUIT"
	exit_script
fi

# Get the current PHP version.
PHP_VERSION=$(php -r "echo PHP_VERSION;")

# Get first three characters from version
readonly PHP_VERSION="${PHP_VERSION:0:3}"

# https://phpunit.de/supported-versions.html
# Currently WordPress only supports up to PHPUnit 7.x
# https://make.wordpress.org/core/handbook/testing/automated-testing/phpunit/#setup
# Set the PHPUnit version if needed.
if [[ -z "$PHPUNIT_VERSION" ]]; then
	case "$PHP_VERSION" in
	7.4 | 7.3 | 7.2)
		PHPUNIT_VERSION=7
		;;
	7.1 | 7.0)
		PHPUNIT_VERSION=6
		;;
	5.6)
		PHPUNIT_VERSION=4
		;;
	*)
		PHPUNIT_VERSION=7
		;;
	esac
fi

readonly PHPUNIT_VERSION="$PHPUNIT_VERSION"

# Install PHPUnit.
printf "Installing PHPUnit %s... \n" "$PHPUNIT_VERSION"
if download "https://phar.phpunit.de/phpunit-$PHPUNIT_VERSION.phar" "phpunit-$PHPUNIT_VERSION.phar"; then
	chmod +x "phpunit-$PHPUNIT_VERSION.phar"
	mv -fv "phpunit-$PHPUNIT_VERSION.phar" /usr/local/bin/phpunit
else
	printf "%s\n" "$QUIT"
	exit_script
fi

# Make .bashrc if not present.
if [[ ! -f "$HOME/.bashrc" ]]; then
	echo "Creating  ~/.bashrc"
	touch "$HOME/.bashrc"
fi

# Set WordPress environment variables.
if [[ -f "$HOME/.bashrc" ]]; then

	# Get the variables.
	source "$HOME/.bashrc"

	if [[ -z "${WP_TESTS_DIR}" ]]; then
		printf "Setting WP_TESTS_DIR environment variable\n"
		echo 'export WP_TESTS_DIR=/tmp/wordpress-tests-lib' >>"$HOME/.bashrc"
	fi
	if [[ -z "${WP_CORE_DIR}" ]]; then
		printf "Setting WP_CORE_DIR environment variable\n"
		echo 'export WP_CORE_DIR=/tmp/wordpress' >>"$HOME/.bashrc"
	fi

	# Get the new variables.
	source "$HOME/.bashrc"
fi

if [[ -z "$WP_CORE_DIR" || -z "$WP_TESTS_DIR" ]]; then
	printf "${RED}ERROR${RESET} The WordPress directories for PHPUnit are not set\n%s\n" "$QUIT"
	exit_script
fi

# Delete tmp files (if they exist).
clean_up_temp_files

# Create tmp directories.
mkdir "/tmp/tmp-wordpress/" || exit
mkdir "/tmp/tmp-wordpress-tests-lib/" || exit

# Create core and tests directories (if needed).
[[ -d "$WP_CORE_DIR" ]] || mkdir "$WP_CORE_DIR" || exit
[[ -d "$WP_TESTS_DIR" ]] || mkdir "$WP_TESTS_DIR" || exit

cd "$WP_CORE_DIR" || exit

# Set default WordPress version.
[[ -z "$WP_VERSION" ]] && WP_VERSION='latest'

# Get the latest WordPress version from API.
#readonly WP_LATEST=$(wget -q -O - "https://api.wordpress.org/core/version-check/1.5/" | head -n 4 | tail -n 1)

# http serves a single offer, whereas https serves multiple. we only want one.
readonly WP_LATEST=$(wget -q -O - "http://api.wordpress.org/core/version-check/1.7/" | grep -o '"version":"[^"]*"' | head -1 | tr -d '"' | awk -F: '{print $2}')

if [[ 'latest' == "$WP_VERSION" ]]; then
	WP_VERSION="$WP_LATEST"
	if [[ -z "$WP_LATEST" ]]; then
		printf "${RED}ERROR${RESET} Could not get latest WordPress version from api.wordpress.org. %s\n%s\n" "$CONNECTION" "$QUIT"
		exit_script
	fi
fi

# Set WordPress version.
readonly WP_VERSION="$WP_VERSION"

# Set default test suite version.
[[ -z "$WP_TS_VERSION" ]] && WP_TS_VERSION="$WP_VERSION"

# Install WordPress.
if [[ 'trunk' == "$WP_VERSION" ]]; then
	printf "Installing WordPress trunk... \n"
	svn export --quiet --force "https://develop.svn.wordpress.org/trunk/src/" "/tmp/tmp-wordpress/"
	rsync -a --delete "/tmp/tmp-wordpress/" "$WP_CORE_DIR"
elif [[ 'nightly' == "$WP_VERSION" ]]; then
	printf "Installing WordPress nightly... \n"
	if download "https://wordpress.org/nightly-builds/wordpress-latest.zip" "/tmp/wordpress-latest.zip"; then
		unzip -o -q "/tmp/wordpress-latest.zip" -d "/tmp/tmp-wordpress/"
		rsync -a --delete "/tmp/tmp-wordpress/wordpress/" "$WP_CORE_DIR"
	fi
else
	printf "Installing WordPress %s... \n" "$WP_VERSION"
	if download "https://wordpress.org/wordpress-$WP_VERSION.tar.gz" "/tmp/wordpress.tar.gz"; then
		tar --strip-components=1 -zxmf "/tmp/wordpress.tar.gz" -C "/tmp/tmp-wordpress/"
		rsync -a --delete "/tmp/tmp-wordpress/" "$WP_CORE_DIR"
	fi
fi

if [[ 'trunk' == "$WP_TS_VERSION" || 'nightly' == "$WP_TS_VERSION" ]]; then
	TS_ARCHIVE="trunk"
elif [[ $WP_TS_VERSION == 'latest' ]]; then
	TS_ARCHIVE="tags/$WP_LATEST"
	WP_TS_VERSION="$WP_LATEST"
else
	TS_ARCHIVE="tags/$WP_TS_VERSION"
fi

# Install WP test suite.
printf "Installing WordPress %s Test Suite...\n" "$WP_TS_VERSION"
if download_test_suite "$TS_ARCHIVE" "$WP_TS_VERSION"; then
	rsync -a --delete "/tmp/tmp-wordpress-tests-lib/" "$WP_TESTS_DIR"
else
	if [[ 'trunk' == "$TS_ARCHIVE" ]]; then
		printf "%s\n" "$QUIT"
		exit_script
	fi

	printf "Installing Test Suite from trunk...\n"
	if download_test_suite "trunk" "trunk"; then
		rsync -a --delete "/tmp/tmp-wordpress-tests-lib/" "$WP_TESTS_DIR"
	else
		printf "%s\n" "$QUIT"
		exit_script
	fi
fi

# Update credentials in the wp-tests-config.php file.
if [[ -f "$WP_TESTS_DIR/wp-tests-config.php" ]]; then
	printf "Updating wp-tests-config.php...\n"
	if [[ $(uname -s) == 'Darwin' ]]; then
		ioption='-i .bak'
	else
		ioption='-i'
	fi

	sed $ioption "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR/wp-tests-config.php"
	sed $ioption "s/youremptytestdbnamehere/wordpress_test/" "$WP_TESTS_DIR/wp-tests-config.php"
	sed $ioption "s/yourusernamehere/root/" "$WP_TESTS_DIR/wp-tests-config.php"
	sed $ioption "s/yourpasswordhere/root/" "$WP_TESTS_DIR/wp-tests-config.php"
fi

# VVV has the tests config outside the $WP_TESTS_DIR dir.
if [[ -f "$WP_TESTS_DIR/wp-tests-config.php" ]]; then
	cp -v "$WP_TESTS_DIR/wp-tests-config.php" "/tmp/wp-tests-config.php"
fi

# Make tests config for develop.git.wordpress.org.
if [[ -f "$LOCAL_PUBLIC/wp-tests-config-sample.php" ]]; then
	printf "Create credentials for wp-tests-config.php...\n"
	sed -e 's/yourusernamehere/root/g' -e 's/yourpasswordhere/root/g' -e 's/youremptytestdbnamehere/wordpress_test/g' $LOCAL_PUBLIC/wp-tests-config-sample.php >$LOCAL_PUBLIC/wp-tests-config.php
fi

# If tests config not present copy to Local's WP root.
if [[ ! -f "$LOCAL_PUBLIC/wp-tests-config.php" ]]; then
	cp -v "$WP_TESTS_DIR/wp-tests-config.php" "$LOCAL_PUBLIC"
fi

# Install database if it doesn't exist.
printf "Checking if database wordpress_test exists\n"
touch /tmp/my.cnf

# Suppress password warnings. It silly I know :-)
printf "[client]\npassword=root\nuser=root" >"/tmp/my.cnf"

# Check if database exists.
database=""
if ! [[ "mysqlshow --version" ]]; then
	database=$(mysqlshow --defaults-file="/tmp/my.cnf" wordpress_test | grep -v Wildcard | grep -o wordpress_test)
elif $(mysql -e 'use wordpress_test'); then
	database="wordpress_test"
fi

if ! [[ "wordpress_test" == "$database" ]]; then
	printf "Creating database wordpress_test\n"
	SOCKET=$(mysqld --verbose --help | grep ^socket | awk '{print $2, $3, $4}')
	PORT=$(mysqld --verbose --help | grep ^port | head -1 | awk '{print $2}')
	#mysqladmin --defaults-file="/tmp/my.cnf" create "wordpress_test" --host="localhost" --port="$PORT" --socket="$SOCKET"
	mysqladmin create "wordpress_test"
else
	printf "Database wordpress_test already exists\n"
fi

# Cleanup files.
clean_up_temp_files

printf "\nFinished setting up packages\n\n"
