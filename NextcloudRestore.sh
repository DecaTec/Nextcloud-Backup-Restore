#!/bin/bash

#
# Bash script for restoring backups of Nextcloud.
# Usage: ./NextcloudRestore.sh <BackupName> (e.g. ./NextcloudRestore.sh 20170910_132703)
# 
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-18-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

# Variables
# TODO: The directory where you store the Nextcloud backups
mainBackupDir="/mnt/Share/NextcloudBackups/"
restore=$1
currentRestoreDir="${mainBackupDir}/${restore}"
# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
nextcloudFileDir="/var/www/nextcloud"
# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located under Nextcloud's file directory (somewhere in the web root), the data directory should not be restored separately
nextcloudDataDir="/var/nextcloud_data"
# TODO: The service name of the web server. Used to start/stop web server (e.g. 'service <webserverServiceName> start')
webserverServiceName="nginx"
# TODO: Your Nextcloud database name
nextcloudDatabase="nextcloud_db"
# TODO: Your Nextcloud database user
dbUser="nextcloud_db_user"
# TODO: The password of the Nextcloud database user
dbPassword="mYpAsSw0rd"
# TODO: Your web server user
webserverUser="www-data"

# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudBackup.sh script.
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDataDir="nextcloud-datadir.tar.gz"
fileNameBackupDb="nextcloud-db.sql"

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

#
# Check if parameter given
#
if [ $# != "1" ]
then
    errorecho "ERROR: No backup name to restore given!"
	errorecho "Usage: NextcloudRestore.sh 'BackupDate'"
    exit 1
fi

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
    errorecho "ERROR: This script has to be run as root!"
    exit 1
fi

#
# Check if backup dir exists
#
if [ ! -d "${currentRestoreDir}" ]
then
	 errorecho "ERROR: Backup ${restore} not found!"
    exit 1
fi

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
cd "${nextcloudFileDir}"
sudo -u "${webserverUser}" php occ maintenance:mode --on
cd ~
echo "Done"
echo

#
# Stop web server
#
echo "Stopping web server..."
service "${webserverServiceName}" stop
echo "Done"
echo

#
# Delete old Nextcloud direcories
#
echo "Deleting old Nextcloud file directory..."
rm -r "${nextcloudFileDir}"
mkdir -p "${nextcloudFileDir}"
echo "Done"
echo

echo "Deleting old Nextcloud data directory..."
rm -r "${nextcloudDataDir}"
mkdir -p "${nextcloudDataDir}"
echo "Done"
echo

#
# Restore file and data directory
#
echo "Restoring Nextcloud file directory..."
tar -xpzf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"
echo "Done"
echo

echo "Restoring Nextcloud data directory..."
tar -xpzf "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"
echo "Done"
echo

#
# Restore database
#
echo "Dropping old Nextcloud DB..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "DROP DATABASE ${nextcloudDatabase}"
echo "Done"
echo

echo "Creating new DB for Nextcloud..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase}"
echo "Done"
echo

echo "Restoring backup DB..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
echo "Done"
echo

#
# Start web server
#
echo "Starting web server..."
service "${webserverServiceName}" start
echo "Done"
echo

#
# Set directory permissions
#
echo "Setting directory permissions..."
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudFileDir}"
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudDataDir}"
echo "Done"
echo

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/13/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "Updating the system data-fingerprint..."
cd "${nextcloudFileDir}"
sudo -u "${webserverUser}" php occ maintenance:data-fingerprint
cd ~
echo "Done"
echo

#
# Disbale maintenance mode
#
echo "Switching off maintenance mode..."
cd "${nextcloudFileDir}"
sudo -u "${webserverUser}" php occ maintenance:mode --off
cd ~
echo "Done"
echo

echo
echo "DONE!"
echo "Backup ${restore} successfully restored."
