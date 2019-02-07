# Automatic restic backups using systemd services and timers

## Purpose of this fork

This fork modifies the [upstream](https://github.com/erikw/restic-systemd-automatic-backup) in a way to be compatible with
Arch Linux packaging standards, and adds a PKGBUILD file to facilitate easier installation on Arch Linux

## Restic

[restic](https://restic.net/) is a command-line tool for making backups, the right way. Check the official website for a feature explanation.

Unfortunately restic does not come pre-configured with a way to run automated backups, say every day. However it's possible to set this up yourself using systemd/cron and some wrappers. This example also features email notifications when a backup fails to complete.

Here follows a step-by step tutorial on how to set it up, with my sample script and configurations that you can modify to suit your needs.

Note, you can use any of the supported [storage backends](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html). The setup should be similar but you will have to use other configuration variables to match your backend of choice.

## Set up

To install on Arch Linux, it should be enough to just pull down the
[PKGBUILD](https://github.com/jat255/restic-systemd-automatic-backup/blob/master/PKGBUILD) file,
run `makepkg`, and install with `pacman`.

```bash
wget https://raw.githubusercontent.com/jat255/restic-systemd-automatic-backup/master/PKGBUILD
makepkg
sudo pacman -U <name of built package>
```

For other flavors of Linux, follow along with the instructions in the [upstream fork](https://github.com/erikw/restic-systemd-automatic-backup).

You will need to edit a couple of configuration files:

| File  | Changes needed |
|---|---|
| `/etc/restic/restic_env.sh`  | Add path to repository and password  |
| `/etc/restic/restic_backup_excludes`  | Add/remove any files/directories to be excluded  |
| `/usr/lib/systemd/system/status-email-user@.service`  | Insert your email address as needed  |

### 3. Initialize remote repo (optional if already done)

Now we must initialize the repository on the remote end:

```bash
source /etc/restic/restic_env.sh
restic init
```

### 4. Script for doing the backup

* `restic_backup.sh`: A script that defines how to run the backup. Edit this file to respect your needs in terms of backup which paths to backup, retention (number of backups to save), etc.

### 5. Make first backup & verify

Now see if the backup itself works, by running

```bash
/usr/bin/restic_backup.sh
restic snapshots
```

Use `sudo` if you're trying to backup root-only readable files.

### 6. Backup automatically; systemd service + timer

Now we can do the modern version of a cron-job, a systemd service + timer, to run the backup every day!

After installing, these files should be in `/usr/lib/systemd/system/` (or put them there manually):

* `restic-backup.service`: A service that calls the backup script.
* `restic-backup.timer`: A timer that starts the backup every day.

Now simply enable the timer with:

```bash
systemctl start restic-backup.timer
systemctl enable restic-backup.timer
```

You can see when your next backup is scheduled to run with

```bash
systemctl list-timers | grep restic
```

and see the status of a currently running backup with

```bash
systemctl status restic-backup
```

or start a backup manually

```bash
systemctl start restic-backup
```

You can follow the backup stdout output live as backup is running with:

```bash
journalctl -f -u restic-backup.service
```

(skip `-f` to see all backups that has run)

### 7. Email notification on failure

We want to be aware when the automatic backup fails, so we can fix it. Since most laptops do not run a mail server, you can send emails with [postfix via Gmail](https://easyengine.io/tutorials/linux/ubuntu-postfix-gmail-smtp/). Follow the instructions over there.

Put this file in `/usr/bin/`:

* `systemd-email`: Sends email using sendmail(1). This script also features time-out for not spamming Gmail servers and getting your account blocked.

Put this file in `/usr/lib/systemd/system/`:

* `status-email-user@.service`: A service that can notify you via email when a systemd service fails. Edit the target email address in this file.

As you maybe noticed already before, `restic-backup.service` is configured to start `status-email-user.service` on failure.

### 8. Optional: automated backup checks

Once in a while it can be good to do a health check of the remote repository, to make sure it's not getting corrupt. This can be done with `$ restic check`.

There are some `*-check*`-files in this git repo. Install these in the same way you installed the `*-backup*`-files.

## What about Cron

If you want to run an all-classic cron job instead, do like this:

* `etc/cron.d/restic`: Depending on your system's cron, put this in `/etc/cron.d/` or similar, or copy the contents to $(sudo crontab -e). The format of this file is tested under FreeBSD, and might need adaptions depending on your cron.
* `usr/bin/cron_mail`: A wrapper for running cron jobs, that sends output of the job as an email using the mail(1) command.