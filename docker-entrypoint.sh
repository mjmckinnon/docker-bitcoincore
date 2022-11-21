#!/bin/sh
set -e

# If we got something like [entrypoint.sh -someargument]
# then change it to [bitcoind -someargument]
if [ $(echo "$1" | cut -c1) = "-" ]; then
	set -- bitcoind "$@"
	echo "$0: process arguments only [$@]"
fi

# If we got [entrypoint.sh bitcoind etc.]  AND user is root then try to
# create datadir and reset perms to bitcoin, then execute this script
# again as bitcoin user, i.e. [entrypoint.sh bitcoind -somearg1 - somearg2]
if [ "$1" = 'bitcoind' -a "$(id -u)" = '0' ]; then
	# Set perms on data
	echo "$0: detected bitcoind as root [$@]"
	mkdir -p "$DATADIR"
	chmod 700 "$DATADIR"
	chown -R bitcoin "$DATADIR"
	exec gosu bitcoin "$0" "$@" -datadir=$DATADIR
fi

# If we got root command for bitcoin-cli or bitcoin-tx as root, run this script
# again as bitcoin user, i.e. [entrypoint.sh bitcoin-xx -somearg1 -somearg2]
if [ "$1" = 'bitcoin-cli' -a "$(id -u)" = '0' ] || [ "$1" = 'bitcoin-tx' -a "$(id -u)" = '0' ]; then
	echo "$0: detected a command as root [$@]"
	exec gosu bitcoin "$0" "$@" -datadir=$DATADIR
fi

# If not root (i.e. docker run --user $USER ...), then run as invoked
echo "$0: running exec"
exec "$@"
