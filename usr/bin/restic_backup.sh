#!/usr/bin/env bash
# Make backup my system with restic
# This script is typically run by: /etc/systemd/system/restic-backup.{service,timer}

# Exit on failure, pipe failure
set -e -o pipefail

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock

	if ! [[ -z ${was_mounted} ]]; then    # test if was_mounted is non-zero
		echo "${directory} was not mounted at start, so unmounting"
		umount ${directory}
	fi

	if ! [[ -z ${ONVPN} ]]; then 		# test if ONVPN is non-zero
		echo "Unmounting carson_mnt on poole.nist.gov"
		ssh jat@poole.nist.gov "fusermount -u carson_mnt" 2> /dev/null
	fi
}
trap exit_hook INT TERM

# check to see if we can ping carson ssh port using nmap
response=$(nmap carson.nist.gov -PN -p ssh 2> /dev/null | grep -Eqs 'open' &> /dev/null; echo $?)
if [ "${response}" == 0 ]; then
    echo "Backup location available, running backup..."
	directory=/mnt/carson_data
else
	# Check to see if we're on VPN
	response=$(nmap carson.nist.gov -PN -p ssh 2> /dev/null | grep -Eqs 'filtered' &> /dev/null; echo $?)
	if [ "${response}" == 0 ]; then
		echo "We appear to be on VPN, running backup..."
		ONVPN=true
		directory=/mnt/carson_data_vpn
		ssh jat@poole.campus.nist.gov "if grep -qs 'carson.nist.gov:/data/users/jtaillon /mnt/carson_data' /proc/mounts; then ; echo \"carson already mounted on poole\"; else; echo \"carson not mounted on poole; mounting\"; sshfs jtaillon@carson.nist.gov:/data/users/jtaillon /mnt/carson_data; fi" 2> /dev/null
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



# How many backups to keep.
RETENTION_HOURS=12
RETENTION_DAYS=7
RETENTION_WEEKS=5
RETENTION_MONTHS=12
RETENTION_YEARS=10

# What to backup, and what to not
BACKUP_PATHS="/"
BACKUP_EXCLUDES="--exclude-file /etc/restic/restic_backup_excludes"
BACKUP_TAG=systemd.timer

# Set all environment variables
source /etc/restic/restic_env.sh

if ! [[ -z ${ONVPN} ]]; then 		# test if ONVPN is non-zero
	echo "Replacing repository path..."
	export RESTIC_REPOSITORY=${RESTIC_REPOSITORY/carson_data/carson_data_vpn}
fi

# NOTE start all commands in background and wait for them to finish.
# Reason: bash ignores any signals while child process is executing and thus my trap exit hook is not triggered.
# However if put in subprocesses, wait(1) waits until the process finishes OR signal is received.
# Reference: https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash

# Remove locks from other stale processes to keep the automated backup running.
GOMAXPROCS=1 restic unlock &
wait $!

# Do the backup!
# See restic-backup(1) or http://restic.readthedocs.io/en/latest/040_backup.html
# --one-file-system makes sure we only backup exactly those mounted file systems specified in $BACKUP_PATHS, and thus not directories like /dev, /sys etc.
# --tag lets us reference these backups later when doing restic-forget.
GOMAXPROCS=1 restic backup \
	--verbose \
	--one-file-system \
	--tag ${BACKUP_TAG} \
	${BACKUP_EXCLUDES} \
	${BACKUP_PATHS} &
wait $!

# Dereference old backups.
# See restic-forget(1) or http://restic.readthedocs.io/en/latest/060_forget.html
# --group-by only the tag and path, and not by hostname. This is because I create a B2 Bucket per host, and if this hostname accidentially change some time, there would now be multiple backup sets.
GOMAXPROCS=1 restic forget \
	--verbose \
	--tag ${BACKUP_TAG} \
	--group-by "paths,tags" \
	--keep-hourly ${RETENTION_HOURS} \
	--keep-daily ${RETENTION_DAYS} \
	--keep-weekly ${RETENTION_WEEKS} \
	--keep-monthly ${RETENTION_MONTHS} \
	--keep-yearly ${RETENTION_YEARS} &
wait $!

# Remove old data not linked anymore.
# See restic-prune(1) or http://restic.readthedocs.io/en/latest/060_forget.html
GOMAXPROCS=1 restic prune \
	--verbose &
wait $!

# Check repository for errors.
# NOTE this takes much time (and data transfer from remote repo?), do this in a separate systemd.timer which is run less often.
#restic check &
#wait $!

echo "Backup & cleaning is done."
