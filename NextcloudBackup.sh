#!/bin/bash

#
# Bash script for creating backups of Nextcloud.
# Usage: ./NextcloudBackup.sh
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-18-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

# Variables
currentDate=$(date +"%Y%m%d_%H%M%S")
# TODO: The directory where you store the Nextcloud backups
backupMainDir="/mnt/Share/NextcloudBackups/"
# The actual directory of the current backup - this is a subdirectory of the main directory above with a timestamp
backupdir="${backupMainDir}/${currentDate}/"
# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
nextcloudFileDir="/var/www/nextcloud"
# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located under Nextcloud's file directory (somewhere in the web root), the data directory should not be a separate part of the backup
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
# TODO: The maximum number of backups to keep (when set to 0, all backups are kept)
maxNrOfBackups=0

# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudRestore.sh script.
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDataDir="nextcloud-datadir.tar.gz"
fileNameBackupDb="nextcloud-db.sql"

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

function DisableMaintenanceMode() {
	echo "Switching off maintenance mode..."
	cd "${nextcloudFileDir}"
	sudo -u "${webserverUser}" php occ maintenance:mode --off
	cd ~
	echo "Done"
	echo
}

# Capture CTRL+C
trap CtrlC INT

function CtrlC() {
	read -p "Backup cancelled. Keep maintenance mode? [y/n] " -n 1 -r
	echo

	if ! [[ $REPLY =~ ^[Yy]$ ]]
	then
		DisableMaintenanceMode
	else
		echo "Maintenance mode still enabled."
	fi

	exit 1
}

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

#
# Check if backup dir already exists
#
if [ ! -d "${backupdir}" ]
then
	mkdir -p "${backupdir}"
else
	errorecho "ERROR: The backup directory ${backupdir} already exists!"
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
# Backup file and data directory
#
echo "Creating backup of Nextcloud file directory..."
tar -cpzf "${backupdir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .
echo "Done"
echo

echo "Creating backup of Nextcloud data directory..."
tar -cpzf "${backupdir}/${fileNameBackupDataDir}"  -C "${nextcloudDataDir}" .
echo "Done"
echo

#
# Backup DB
#
echo "Backup Nextcloud database..."
mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${backupdir}/${fileNameBackupDb}"
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
# Disable maintenance mode
#
DisableMaintenanceMode()

#
# Delete old backups
#
if (( ${maxNrOfBackups} != 0 ))
then
	nrOfBackups=$(ls -l ${backupMainDir} | grep -c ^d)

	if (( ${nrOfBackups} > ${maxNrOfBackups} ))
	then
		echo "Removing old backups..."
		ls -t ${backupMainDir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read dirToRemove; do
			echo "${dirToRemove}"
			rm -r ${backupMainDir}/${dirToRemove}
			echo "Done"
			echo
		done
	fi
fi

echo
echo "DONE!"
echo "Backup created: ${backupdir}"
