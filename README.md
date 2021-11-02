# Nextcloud-Backup-Restore

This repository contains two bash scripts for backup/restore of [Nextcloud](https://nextcloud.com/).

It is based on a Nextcloud installation using nginx and MariaDB (see the (German) tutorial [Nextcloud auf Ubuntu Server 20.04 LTS mit nginx, MariaDB, PHP, Let’s Encrypt, Redis und Fail2ban](https://decatec.de/home-server/nextcloud-auf-ubuntu-server-20-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/)).

## General information

For a complete backup of any Nextcloud instance, you'll have to backup these items:
- The Nextcloud file directory (usually */var/www/nextcloud*)
- The data directory of Nextcloud (it's recommended that this is *not* located in the web root, so e.g. */var/nextcloud_data*)
- The Nextcloud database
- Maybe a local external storage mounted into Nextcloud

The scripts take care of these items to backup automatically.

## Requirements

- *pigz* (https://zlib.net/pigz/) when using backup compression. If not available, you can use another compression algorithm (e.g. gzip)

**Important:**

- After cloning or downloading the repository, you'll have to edit the scripts so that they represent your current Nextcloud installation (directories, users, etc.). All values which need to be customized are marked with *TODO* in the script's comments.
- The scripts assume that Nextcloud's data directory is *not* a subdirectory of the Nextcloud installation (file directory). The general recommendation is that the data directory should not be located somewhere in the web folder of your webserver (usually */var/www/*), but in a different folder (e.g. */var/nextcloud_data*). For more information, see [here](https://docs.nextcloud.com/server/latest/admin_manual/installation/installation_wizard.html#data-directory-location-label).
- However, if your data directory *is* located under the Nextcloud file directory, you'll have to change the scripts so that the data directory is not part of the backup/restore (otherwise, it would be copied twice).
- The scripts only backup the Nextcloud data directory and can backup a local external storage mounted into Nextcloud. If you have any other external storage mounted in Nextcloud (e.g. FTP), these files have to be handled separately.
- The scripts support MariaDB/MySQL and PostgreSQL as database.
- You should have enabled 4 byte support (see [Nextcloud Administration Manual](https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/mysql_4byte_support.html)) on your Nextcloud database. Otherwise, when you have *not* enabled 4 byte support, you have to edit the restore script, so that the database is not created with 4 byte support enabled (variable `dbNoMultibyte`).

## Setup

1. Clone the repository: `git clone https://codeberg.org/DecaTec/Nextcloud-Backup-Restore.git`
2. Set permissions:
    - `chown -R root Nextcloud-Backup-Restore`
    - `cd Nextcloud-Backup-Restore`
    - `chmod 700 *.sh`
3. Call the (interactive) script for automated setup (this will modify the scripts for backup/restore to fit your Nextcloud instance, see below): `./setup.sh`
4. **Important**: Check the scripts `NextcloudBackup.sh` and `NextcloudRestore.sh` if everything was set up correctly (see *TODO* in the script's comments)
5. Start using the scripts: See sections *Backup* and *Restore* below

### Automated setup

Next to the backup/restore scripts, there is another script (`setup.sh`). The setup script gathers some information and uses the [OCC command](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/occ_command.html) in order to set the required variables in the backup/restore scripts automatically. This way, the configuration of the backup/restore scripts can be automated to some extend.

## Backup

In order to create a backup, simply call the script *NextcloudBackup.sh* on your Nextcloud machine.
If this script is called without parameter, the backup is saved in a directory with the current time stamp in your main backup directory: As an example, this would be */media/hdd/nextcloud_backup/20170910_132703*.
The backup script can also be called with a parameter specifiying the main backup directory, e.g. *./NextcloudBackup.sh /media/hdd/nextcloud_backup*. In this case, the directory specified will be used as main backup directory. 

You can also call this script by cron. Example (at 2am every night, with log output):

`0 2 * * * /path/to/scripts/Nextcloud-Backup-Restore/NextcloudBackup.sh  > /path/to/logs/Nextcloud-Backup-$(date +\%Y\%m\%d\%H\%M\%S).log 2>&1`

## Restore

For restore, just call *NextcloudRestore.sh*. This script expects at least one parameter specifying the name of the backup to be restored. In our example, this would be *20170910_132703* (the time stamp of the backup created before). The full command for a restore would be *./NextcloudRestore.sh 20170910_132703*.
You can also specify the main backup directory with a second parameter, e.g. *./NextcloudRestore.sh 20170910_132703 /media/hdd/nextcloud_backup*.