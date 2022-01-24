# Changelog

## 3.0.3

### General
- Variable `includeUpdaterBackups` in `NextcloudBackupRestore.conf.sample`

### Backup
- Bugfix: The backup directory was not recognized when given by parameter

## 3.0.2

### Backup
- Bugfix: When calling the backup script by cron, the configuration file `NextcloudBackupRestore.conf` could not be found

## 3.0.1

### Backup
- Bugfix: Option to include/ignore backups from the Nextcloud updater was not set correctly during setup

## 3.0.0

### General
- Backup/restore scripts now use a central configuration file (`NextcloudBackupRestore.conf`)
- This configuration file includes all the settings which should be configured to match the specific Nextcloud instance. This simplifies the initial configuration of the backup/restore scripts
- The setup (`setup.sh`) creates this central configuration file (`NextcloudBackupRestore.conf`) rather than modifying the backup/restore scripts
- Bugfix: setup.sh won't set wrong database password if password contains slashes and/or backslashes

### Restore
- While restore, only the contents of Nextcloud's data directory gets removed, rather than the whole directory (useful when the data directory is stored directly in a mounted drive)

## 2.3.3

### Restore
- Update fingerprint after disabling maintenance mode

## 2.3.2

### Restore
- Bugfix: Compression command on restore

### Setup
- Hint for installing pigz when using compression
- Bugfix: Set variable `backupMainDir` correctly

## 2.3.1

### General
- Bugfix: Unbound variable when no parameters are supplied

## 2.3.0

### General
- The scripts now exit when any command fails.
- Defined the command for compression in the "TODO section" of the script for easier customization.
- Added section for setup in readme.
- Updated links. 
- Document requirement pigz when using compression.
- Formatting.

### Backup
- Bugfix: Fixed the double trailing slash for paths containing the variable `backupdir`.

## 2.2.0

### General
- Better handling of external data directory: Backup/restore of external data direcrory is done automatically if the variable `nextcloudLocalExternalDataDir` is set.

## 2.1.3

### General
- Added timestamps for every step.

## 2.1.2

### General
- Use pigz for compression.

## 2.1.1

### Backup
- Optimized cleaning up of old backups.

## 2.1.0

### General
- Added a variable *useCompression* to use compression (.tar.gz) for file and data directory (enabled by default, this was also the default behavior before this option was implemented). 
- You can disable compression of these directories (.tar) if you use some other (archiving) backup mechanism which utilizes the Nextcloud backup and restore scripts (e.g. Borg Backup, see here: https://codeberg.org/DecaTec/Linux-Server-Backup)

## 2.0.0

### General
- Added script (`setup.sh`) for an (more or less) automated setup of the backup and restore scripts (utilizing OCC in order to gather information about Nextcloud instance).

## 1.1.1

### Backup
- When a backup is cancelled, the webserver is restartet automatically.

## 1.1.0

### Backup
- New variable *ignoreUpdaterBackups*: When set to true, the backups of Nextcloud's updater are not included in the backups (default: *false*).

## 1.0.0

### General
- Versioning of Nextcloud-Backup-Restore.
- The database system (MySQL/MariaDB or PostgreSQL) is configured in the variable area of the scripts, so it's not necessary to comment/uncomment the specific database commands.
- Special characters for the database password can be used now.
- Single quotes for variables.

### Restore
- The commands for restoring the database are checked at the beginning of the script. Is the specific database system is not installed, the restore is cancelled.
- The default main backup directory now is the same as in the backup script.