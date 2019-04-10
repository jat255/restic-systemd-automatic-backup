#!/usr/bin/env bash
# Check my backup with  restic to Backblaze B2 for errors.
# This script is typically run by: /etc/systemd/system/restic-check.{service,timer}

# Exit on failure, pipe failure
set -e -o pipefail

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock

	if ! [[ -z was_mounted ]]; then
		echo "${directory} was not mounted at start, so unmounting"
		umount ${directory}
	fi
}
trap exit_hook INT TERM

# check to see if we can ping carson ssh port using nmap
response=$(nmap carson.nist.gov -PN -p ssh 2> /dev/null | grep -Eqs 'open' &> /dev/null; echo $?)
if [ "${response}" == 0 ]; then
    echo "Backup location connected, running backup..."
	directory=/mnt/carson_data
else
	# Check to see if we're on VPN
	response=$(nmap carson.nist.gov -PN -p ssh 2> /dev/null | grep -Eqs 'filtered' &> /dev/null; echo $?)
	if [ "${response}" == 0 ]; then
		echo "We appear to be on VPN, running backup..."
		directory=/mnt/carson_data_vpn
	else
		# we should exit
		echo "Could not connect to backup location; skipping backup"
		exit 1
	fi
fi

if mount | grep ${directory} > /dev/null; then
    echo "${directory} is already mounted"
	was_mounted=true
else
	echo "mounting ${directory}"
    mount ${directory}
fi



source /etc/restic/restic_env.sh

# Remove locks from other stale processes to keep the automated backup running.
# NOTE nope, dont' unlock like restic_backup.sh. restic_backup.sh should take preceedance over this script.
#restic unlock &
#wait $!

# Check repository for errors.
restic check \
	--verbose &
wait $!
