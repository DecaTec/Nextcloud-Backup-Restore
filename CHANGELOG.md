# Changelog

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