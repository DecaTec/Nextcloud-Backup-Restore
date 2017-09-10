# Nextcloud-Backup-Restore

This repository contains two bash scripts for backup/restore of [Nextcloud](https://nextcloud.com/).

It is based on a Nextcloud installation using nginx and MariaDB (see the (German) tutorial [Nextcloud auf Ubuntu Server mit nginx, MariaDB, PHP, Let’s Encrypt, Redis und Fail2ban](https://decatec.de/home-server/nextcloud-auf-ubuntu-server-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/)).

## Usage

**Important**

After cloning or downloading the repository, you'll have to edit the scripts so that they represent your current Nextcloud installation (directories, users, etc.)

## General information

For a complete backup of any Nextcloud instance, you'll have to backup three items:
- The Nextcloud file directory (usually */var/www/nextcloud*)
- The data directory of Nextcloud (it's recommended to locate this not under the web root, so e.g. */var/nextcloud_data*)
- The Nextcloud database

The scripts take care of these three items to backup automatically.

### Backup

In oder to create a backup, simplly call the script *NextcloudBackup.sh* on your Nextcloud machine.
This will create a direcotry with the current time stamp in your main backup directory (you already edited the script so that it fits yout Nextcloud installation, haven't you): As an example, this would be */mnt/Share/NextcloudBackups/20170910_132703*.

### Restore

For restore, just call *NextcloudRestore.sh*. This script expects one parameter which is the name of the backup to be restored. In our example, this would be *20170910_132703* (the time stamp of the backup created before). So the full command for a restore would be *./NextcloudRestore.sh 20170910_132703*.