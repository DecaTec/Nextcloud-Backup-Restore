#!/bin/bash

#
# Bash script an easy setup of NextcloudBackup.sh and NextcloudRestore.sh
#
# Version 2.3.4
#
# Usage:
# 	- call the setup.sh script
#   - Enter the required information
#   - You NextcloudBackup.sh and NextcloudRestore.sh scripts will be tailored to match you installation.
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-18-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#

#
# IMPORTANT
# The setup.sh script automated the configuration for the backup/restore scripts.
# However, you should always check the backup/restore config BEFORE executing these!
#

# Make sure the script exits when any command fails
set -Eeuo pipefail

#
# Pre defined variables
#
backupMainDir='/media/hdd/nextcloud_backup'
nextcloudFileDir='/var/www/nextcloud'
webserverUser='www-data'
webserverServiceName='nginx'
NextcloudBackupRestoreConf='NextcloudBackupRestore.conf'  # Holds the configuration for NextcloudBackup.sh and NextcloudRestore.sh

#
# Gather information
#
clear

echo "Enter the directory to which the backups should be saved."
echo "Default: ${backupMainDir}"
echo ""
read -p "Enter a directory or press ENTER if the backup directory should be ${backupMainDir}: " BACKUPMAINDIR

[ -z "$BACKUPMAINDIR" ] ||  backupMainDir=$BACKUPMAINDIR
clear

echo "Enter the path to the Nextcloud file directory."
echo "Usually: ${nextcloudFileDir}"
echo ""
read -p "Enter a directory or press ENTER if the file directory is ${nextcloudFileDir}: " NEXTCLOUDFILEDIRECTORY

[ -z "$NEXTCLOUDFILEDIRECTORY" ] ||  nextcloudFileDir=$NEXTCLOUDFILEDIRECTORY
clear

echo "Enter the webserver user."
echo "Usually: ${webserverUser}"
echo ""
read -p "Enter an new user or press ENTER if the webserver user is ${webserverUser}: " WEBSERVERUSER

[ -z "$WEBSERVERUSER" ] ||  webserverUser=$WEBSERVERUSER
clear

echo "Enter the webserver service name."
echo "Usually: nginx or apache2"
echo ""
read -p "Enter an new webserver service name or press ENTER if the webserver service name is ${webserverServiceName}: " WEBSERVERSERVICENAME

[ -z "$WEBSERVERSERVICENAME" ] ||  webserverServiceName=$WEBSERVERSERVICENAME
clear

echo "Should the backed up data be compressed?"
echo ""
read -p "Should the backed up data be compressed? [y/N]: " USECOMPRESSION

useCompression=true
if [ "$USECOMPRESSION" != 'y' ] ; then
  useCompression=false
fi

clear

echo "Backup directory: ${backupMainDir}"
echo "Nextcloud file directory: ${nextcloudFileDir}"
echo "Webserver user: ${webserverUser}"
echo "Webserver service name: ${webserverServiceName}"

if [ "$useCompression" = true ] ; then
	echo "Compression: yes"
else
  	echo "Compression: no"
fi

read -p "Is the information correct? [y/N] " CORRECTINFO

if [ "$CORRECTINFO" != 'y' ] ; then
  echo "ABORTING!"
  echo "No file has been altered."
  exit 1
fi

function occ_get() {
	sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ config:system:get "$1"
}

# Make test call to OCC
occ_get datadirectory

if [ $? -ne 0 ]; then
    echo "Error calling OCC: Please check if the information provided was correct."
    echo "ABORTING!"
  	echo "No file has been altered."
  	exit 1
fi

#
# Read data from OCC and write to config file.
#

if [ -e "$NextcloudBackupRestoreConf" ] ; then
  echo -e "\n\nSaving existing $NextcloudBackupRestoreConf to ${NextcloudBackupRestoreConf}_bak"
  cp --force "$NextcloudBackupRestoreConf" "${NextcloudBackupRestoreConf}_bak"
fi

echo ""
echo ""
echo "Creating $NextcloudBackupRestoreConf to match your installation..."
echo ""

# Nextcloud data dir
nextcloudDataDir=$(occ_get datadirectory)

# Database system
databaseSystem=$(occ_get dbtype)

# PostgreSQL is identified as pgsql
if [ "${databaseSystem,,}" = "pgsql" ]; then
  databaseSystem='postgresql';
fi

# Database
nextcloudDatabase=$(occ_get dbname)

# Database user
dbUser=$(occ_get dbuser)

# Database password
dbPassword=$(occ_get dbpassword)

# File names for backup files
fileNameBackupFileDir='nextcloud-filedir.tar'
fileNameBackupDataDir='nextcloud-datadir.tar'

if [ "$useCompression" = true ] ; then
	fileNameBackupFileDir='nextcloud-filedir.tar.gz'
	fileNameBackupDataDir='nextcloud-datadir.tar.gz'
fi

fileNameBackupExternalDataDir=''

if [ ! -z "${nextcloudLocalExternalDataDir+x}" ] ; then
	fileNameBackupExternalDataDir='nextcloud-external-datadir.tar'

	if [ "$useCompression" = true ] ; then
		fileNameBackupExternalDataDir='nextcloud-external-datadir.tar.gz'
	fi
fi

fileNameBackupDb='nextcloud-db.sql'

{ echo '# Configuration for Nextcloud-Backup-Restore scripts'
  echo ''
  echo "backupMainDir='$backupMainDir'"                # Backup main dir
  echo ''
  echo '# TODO: Use compression for file/data dir'
  echo '# When this is the only script for backups, it is recommend to enable compression.'
  echo '# If the output of this script is used in another (compressing) backup (e.g. borg backup),'
  echo '# you should probably disable compression here and only enable compression of your main backup script.'
  echo 'useCompression=true'
  echo ''
  echo '# TOOD: The bare tar command for using compression while backup.'
  echo "# Use 'tar -cpzf' if you want to use gzip compression."
  echo 'compressionCommand="tar -I pigz -cpf"'
  echo ''
  echo '# TOOD: The bare tar command for using compression while restoring.'
  echo "# Use 'tar -xmpzf' if you want to use gzip compression."
  echo 'extractCommand="tar -I pigz -xmpf"'
  echo ''
  echo "# File names for backup files"
  echo "fileNameBackupFileDir='$fileNameBackupFileDir'"
  echo "fileNameBackupDataDir='$fileNameBackupDataDir'"
  echo "fileNameBackupExternalDataDir='$fileNameBackupExternalDataDir'"
  echo "fileNameBackupDb='$fileNameBackupDb'"
  echo ''
  echo '# TODO: The directory of your Nextcloud installation (this is a directory under your web root)'
  echo "nextcloudFileDir='$nextcloudFileDir'"
  echo ''
  echo '# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)'
  echo "# If your data directory is located under Nextcloud's file directory (somewhere in the web root),"
  echo '# the data directory should not be a separate part of the backup'
  echo "nextcloudDataDir='$nextcloudDataDir'"
  echo ''
  echo "# TODO: The directory of your Nextcloud's local external storage."
  echo '# Uncomment if you use local external storage.'
  echo "#nextcloudLocalExternalDataDir='/var/nextcloud_external_data'"
  echo ''
  echo "# TODO: The service name of the web server. Used to start/stop web server (e.g. 'systemctl start <webserverServiceName>')"
  echo "webserverServiceName='$webserverServiceName'"
  echo ''
  echo '# TODO: Your web server user'
  echo "webserverUser='$webserverUser'"
  echo ''
  echo "# TODO: The name of the database system (one of: mysql, mariadb, postgresql)"
  echo "databaseSystem='$databaseSystem'"
  echo ''
  echo '# TODO: Your Nextcloud database name'
  echo "nextcloudDatabase='$nextcloudDatabase'"
  echo ''
  echo '# TODO: Your Nextcloud database user'
  echo "dbUser='$dbUser'"
  echo ''
  echo '# TODO: The password of the Nextcloud database user'
  echo "dbPassword='$dbPassword'"
  echo ''
  echo '# TODO: The maximum number of backups to keep (when set to 0, all backups are kept)'
  echo 'maxNrOfBackups=0'
  echo ''
  echo "# TODO: Ignore updater's backup directory in the data directory to save space"
  echo '# Set to true to ignore the backup directory'
  echo 'ignoreUpdaterBackups=false'
  echo ''
} > ./"${NextcloudBackupRestoreConf}"

echo ""
echo "Done!"
echo ""
echo ""
echo "IMPORTANT: Please check $NextcloudBackupRestoreConf if all variables were set correctly BEFORE running these scripts!"
echo ""
echo "When using pigz compression, you also have to install pigz (e.g. for Debian/Ubuntu: apt install pigz)"
echo ""
echo ""
