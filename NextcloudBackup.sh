#!/bin/bash

#
# Bash script for creating backups of Nextcloud.
#
# Version 3.0.3
#
# Requirements:
#	- pigz (https://zlib.net/pigz/) for using backup compression. If not available, you can use another compression algorithm (e.g. gzip)
#
# Supported database systems:
# 	- MySQL/MariaDB
# 	- PostgreSQL
#
# Usage:
# 	- With backup directory specified in the script:  ./NextcloudBackup.sh
# 	- With backup directory specified by parameter: ./NextcloudBackup.sh <backupDirectory> (e.g. ./NextcloudBackup.sh /media/hdd/nextcloud_backup)
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-20-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#


# Make sure the script exits when any command fails
set -Eeuo pipefail

# Variables
working_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
configFile="${working_dir}/NextcloudBackupRestore.conf"   # Holds the configuration for NextcloudBackup.sh and NextcloudRestore.sh
_backupMainDir=${1:-}

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

#
# Check if config file exists
#
if [ ! -f "${configFile}" ]
then
	errorecho "ERROR: Configuration file $configFile cannot be found!"
	errorecho "Please make sure that a configuratrion file '$configFile' is present in the main directory of the scripts."
	errorecho "This file can be created automatically using the setup.sh script."
	exit 1
fi

source "$configFile" || exit 1  # Read configuration variables

if [ -n "$_backupMainDir" ]; then
	backupMainDir=$(echo $_backupMainDir | sed 's:/*$::')
fi

currentDate=$(date +"%Y%m%d_%H%M%S")

# The actual directory of the current backup - this is a subdirectory of the main directory above with a timestamp
backupDir="${backupMainDir}/${currentDate}"

function DisableMaintenanceMode() {
	echo "$(date +"%H:%M:%S"): Switching off maintenance mode..."
	sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:mode --off
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

	echo "Starting web server..."
	systemctl start "${webserverServiceName}"
	echo "Done"
	echo

	exit 1
}

#
# Print information
#
echo "Backup directory: ${backupMainDir}"

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
if [ ! -d "${backupDir}" ]
then
	mkdir -p "${backupDir}"
else
	errorecho "ERROR: The backup directory ${backupDir} already exists!"
	exit 1
fi

#
# Set maintenance mode
#
echo "$(date +"%H:%M:%S"): Set maintenance mode for Nextcloud..."
sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:mode --on
echo "Done"
echo

#
# Stop web server
#
echo "$(date +"%H:%M:%S"): Stopping web server..."
systemctl stop "${webserverServiceName}"
echo "Done"
echo

#
# Backup file directory
#
echo "$(date +"%H:%M:%S"): Creating backup of Nextcloud file directory..."

if [ "$useCompression" = true ] ; then
	`$compressionCommand "${backupDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .`
else
	tar -cpf "${backupDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .
fi

echo "Done"
echo

#
# Backup data directory
#
echo "$(date +"%H:%M:%S"): Creating backup of Nextcloud data directory..."

if [ "$includeUpdaterBackups" = false ] ; then
	echo "Ignoring Nextcloud updater backup directory"

	if [ "$useCompression" = true ] ; then
		`$compressionCommand "${backupDir}/${fileNameBackupDataDir}"  --exclude="updater-*/backups/*" -C "${nextcloudDataDir}" .`
	else
		tar -cpf "${backupDir}/${fileNameBackupDataDir}"  --exclude="updater-*/backups/*" -C "${nextcloudDataDir}" .
	fi
else
	if [ "$useCompression" = true ] ; then
		`$compressionCommand "${backupDir}/${fileNameBackupDataDir}"  -C "${nextcloudDataDir}" .`
	else
		tar -cpf "${backupDir}/${fileNameBackupDataDir}"  -C "${nextcloudDataDir}" .
	fi
fi

echo "Done"
echo

#
# Backup local external storage.
#
if [ ! -z "${nextcloudLocalExternalDataDir+x}" ] ; then
	echo "$(date +"%H:%M:%S"): Creating backup of Nextcloud local external storage directory..."

	if [ "$useCompression" = true ] ; then
		`$compressionCommand "${backupDir}/${fileNameBackupExternalDataDir}"  -C "${nextcloudLocalExternalDataDir}" .`
	else
		tar -cpf "${backupDir}/${fileNameBackupExternalDataDir}"  -C "${nextcloudLocalExternalDataDir}" .
	fi

	echo "Done"
	echo
fi

#
# Backup DB
#
if [ "${databaseSystem,,}" = "mysql" ] || [ "${databaseSystem,,}" = "mariadb" ]; then
  	echo "$(date +"%H:%M:%S"): Backup Nextcloud database (MySQL/MariaDB)..."

	if ! [ -x "$(command -v mysqldump)" ]; then
		errorecho "ERROR: MySQL/MariaDB not installed (command mysqldump not found)."
		errorecho "ERROR: No backup of database possible!"
	else
		mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${backupDir}/${fileNameBackupDb}"
	fi

	echo "Done"
	echo
elif [ "${databaseSystem,,}" = "postgresql" ] || [ "${databaseSystem,,}" = "pgsql" ]; then
	echo "$(date +"%H:%M:%S"): Backup Nextcloud database (PostgreSQL)..."

	if ! [ -x "$(command -v pg_dump)" ]; then
		errorecho "ERROR: PostgreSQL not installed (command pg_dump not found)."
		errorecho "ERROR: No backup of database possible!"
	else
		PGPASSWORD="${dbPassword}" pg_dump "${nextcloudDatabase}" -h localhost -U "${dbUser}" -f "${backupDir}/${fileNameBackupDb}"
	fi

	echo "Done"
	echo
fi

#
# Start web server
#
echo "$(date +"%H:%M:%S"): Starting web server..."
systemctl start "${webserverServiceName}"
echo "Done"
echo

#
# Disable maintenance mode
#
DisableMaintenanceMode

#
# Delete old backups
#
if [ ${maxNrOfBackups} != 0 ]
then
	nrOfBackups=$(ls -l ${backupMainDir} | grep -c ^d)

	if [ ${nrOfBackups} -gt ${maxNrOfBackups} ]
	then
		echo "$(date +"%H:%M:%S"): Removing old backups..."
		ls -t ${backupMainDir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read -r dirToRemove; do
			echo "${dirToRemove}"
			rm -r "${backupMainDir}/${dirToRemove:?}"
			echo "Done"
			echo
		done
	fi
fi

echo
echo "DONE!"
echo "$(date +"%H:%M:%S"): Backup created: ${backupDir}"
