# Not file targets.
.PHONY: help install install-scripts install-conf install-exclude install-systemd

### Macros ###
SRCS_SCRIPTS	= $(filter-out %cron_mail, $(wildcard usr/bin/*))
SRCS_CONF		= $(wildcard etc/restic/*)
SRCS_SYSTEMD	= $(wildcard usr/lib/systemd/system/*)

# Just set PREFIX in envionment, like
# $ PREFIX=/tmp/test make
DEST_SCRIPTS	= $(PREFIX)/usr/bin
DEST_CONF		= $(PREFIX)/etc/restic
DEST_SYSTEMD	= $(PREFIX)/usr/lib/systemd/system
DEST_LICENSE	= $(PREFIX)/usr/share/licenses/restic-systemd-automatic-backup-git


### Targets ###
# target: all - Default target.
all: install

# target: help - Display all targets.
help:
	@egrep "#\starget:" [Mm]akefile  | sed 's/\s-\s/\t\t\t/' | cut -d " " -f3- | sort -d

# target: install - Install all files
install: install-scripts install-conf install-systemd

# target: install-scripts - Install executables.
install-scripts:
	$(info install-scripts)
	$(info SRCS_SCRIPTS is $(SRCS_SCRIPTS))
	install -d $(DEST_SCRIPTS)
	install -m 755 $(SRCS_SCRIPTS) $(DEST_SCRIPTS)
	install -d $(DEST_LICENSE)
	install -m 644 LICENSE $(DEST_LICENSE)
	
# target: install-conf - Install restic configuration files.
install-conf:
	$(info install-conf)
	install -d $(DEST_CONF) -m 700
	install $(SRCS_CONF) $(DEST_CONF)

# target: install-systemd - Install systemd timer and service files
install-systemd:
	$(info install-systemd)
	install -d $(DEST_SYSTEMD)
	install -m 0755 $(SRCS_SYSTEMD) $(DEST_SYSTEMD)
