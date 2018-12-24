# Nextcloud-Backup-Restore

This repository contains two bash scripts for backup/restore of [Nextcloud](https://nextcloud.com/).

It is based on a Nextcloud installation using nginx and MariaDB (see the (German) tutorial [Nextcloud auf Ubuntu Server 18.04 LTS mit nginx, MariaDB, PHP, Let’s Encrypt, Redis und Fail2ban](https://decatec.de/home-server/nextcloud-auf-ubuntu-server-18-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/)).

## General information

For a complete backup of any Nextcloud instance, you'll have to backup three items:
- The Nextcloud file directory (usually */var/www/nextcloud*)
- The data directory of Nextcloud (it's recommended to locate this not under the web root, so e.g. */var/nextcloud_data*)
- The Nextcloud database

The scripts take care of these three items to backup automatically.

**Important:**

- After cloning or downloading the repository, you'll have to edit the scripts so that they represent your current Nextcloud installation (directories, users, etc.). All values which need to be customized are marked with *TODO* in the script's comments.
- The scripts assume that Nextcloud's data directory is *not* a subdirectory of the Nextcloud installation (file directory). The general recommendation is that the data directory should not be located somewhere in the web folder of your webserver (usually */var/www/*), but in a different folder (e.g. */var/nextcloud_data*). For more information, see [here](https://docs.nextcloud.com/server/15/admin_manual/installation/installation_wizard.html#data-directory-location-label).
- However, if your data directory *is* located under the Nextcloud file directory, you'll have to change the scripts so that the data directory is not part of the backup/restore (otherwise, it would be copied twice).
- The scripts only backup the Nextcloud data directory. If you have any external storage mounted in Nextcloud, these directories have to be handled separately.
- The scripts assume that you are using MySQL/MariaDB as database for Nextcloud. However, it also supports PostreSQL databases. In this case you have to uncomment the parts of backing up/restoring the database.
- You should have enabled 4 byte support (see [Nextcloud Administration Manual](https://docs.nextcloud.com/server/15/admin_manual/configuration_database/mysql_4byte_support.html)) on your Nextcloud database. Otherwise, when you have *not* enabled 4 byte support, you have to edit the restore script, so that the database is not created with 4 byte support enabled.

## Backup

In order to create a backup, simply call the script *NextcloudBackup.sh* on your Nextcloud machine.
This will create a directory with the current time stamp in your main backup directory (you already edited the script so that it fits your Nextcloud installation, haven't you): As an example, this would be */mnt/Share/NextcloudBackups/20170910_132703*.

## Restore

For restore, just call *NextcloudRestore.sh*. This script expects one parameter which is the name of the backup to be restored. In our example, this would be *20170910_132703* (the time stamp of the backup created before). The full command for a restore would be *./NextcloudRestore.sh 20170910_132703*.
