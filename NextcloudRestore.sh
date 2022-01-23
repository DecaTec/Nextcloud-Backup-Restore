#!/bin/bash

#
# Bash script for restoring backups of Nextcloud.
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
#   - With backup directory specified in the script: ./NextcloudRestore.sh <BackupName> (e.g. ./NextcloudRestore.sh 20170910_132703)
#   - With backup directory specified by parameter: ./NextcloudRestore.sh <BackupName> <BackupDirectory> (e.g. ./NextcloudRestore.sh 20170910_132703 /media/hdd/nextcloud_backup)
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-20-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#


# Make sure the script exits when any command fails
set -Eeuo pipefail

# Variables
working_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
configFile="${working_dir}/NextcloudBackupRestore.conf"   # Holds the configuration for NextcloudBackup.sh and NextcloudRestore.sh
restore=${1:-}
_backupMainDir=${2:-}

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

#
# Check if config file exists
#
if [ ! -f "${configFile}" ]
then
	errorecho "ERROR: Configuration file $configFile cannot be found!"
    errorecho "Please make sure that a configuration file '$configFile' is present in the main directory of the scripts."
    errorecho "This file can be created automatically using the setup.sh script."
    exit 1
fi

source "$configFile" || exit 1  # Read configuration variables

if [ -n "$_backupMainDir" ]; then
	backupMainDir="$_backupMainDir"
fi

echo "Backup directory: $backupMainDir"

currentRestoreDir="${backupMainDir}/${restore}"

#
# Check if parameter(s) given
#
if [ $# != "1" ] && [ $# != "2" ]
then
    errorecho "ERROR: No backup name to restore given, or wrong number of parameters!"
    errorecho "Usage: NextcloudRestore.sh 'BackupDate' ['BackupDirectory']"
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
# Check if the commands for restoring the database are available
#
if [ "${databaseSystem,,}" = "mysql" ] || [ "${databaseSystem,,}" = "mariadb" ]; then
    if ! [ -x "$(command -v mysql)" ]; then
		errorecho "ERROR: MySQL/MariaDB not installed (command mysql not found)."
		errorecho "ERROR: No restore of database possible!"
        errorecho "Cancel restore"
        exit 1
    fi
elif [ "${databaseSystem,,}" = "postgresql" ] || [ "${databaseSystem,,}" = "pgsql" ]; then
    if ! [ -x "$(command -v psql)" ]; then
		errorecho "ERROR: PostgreSQL not installed (command psql not found)."
		errorecho "ERROR: No restore of database possible!"
        errorecho "Cancel restore"
        exit 1
	fi
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
# Delete old Nextcloud directories
#

# File directory
echo "$(date +"%H:%M:%S"): Deleting old Nextcloud file directory..."
rm -rf "${nextcloudFileDir}"
mkdir -p "${nextcloudFileDir}"
echo "Done"
echo

# Data directory
echo "$(date +"%H:%M:%S"): Deleting old Nextcloud data directory..."
rm -rf "${nextcloudDataDir}/*"

echo "Done"
echo

# Local external storage
if [ ! -z "${nextcloudLocalExternalDataDir+x}" ] ; then
    echo "Deleting old Nextcloud local external storage directory..."
    rm -rf "${nextcloudLocalExternalDataDir}/*"
    echo "Done"
    echo
fi

#
# Restore file and data directory
#

# File directory
echo "$(date +"%H:%M:%S"): Restoring Nextcloud file directory..."

if [ "$useCompression" = true ] ; then
    `$extractCommand "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"`
else
    tar -xmpf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"
fi

echo "Done"
echo

# Data directory
echo "$(date +"%H:%M:%S"): Restoring Nextcloud data directory..."

if [ "$useCompression" = true ] ; then
    `$extractCommand "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"`
else
    tar -xmpf "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"
fi

echo "Done"
echo

# Local external storage
if [ ! -z "${nextcloudLocalExternalDataDir+x}" ] ; then
    echo "$(date +"%H:%M:%S"): Restoring Nextcloud local external storage directory..."

    if [ "$useCompression" = true ] ; then
        `$extractCommand "${currentRestoreDir}/${fileNameBackupExternalDataDir}" -C "${nextcloudLocalExternalDataDir}"`
    else
        tar -xmpf "${currentRestoreDir}/${fileNameBackupExternalDataDir}" -C "${nextcloudLocalExternalDataDir}"
    fi

    echo "Done"
    echo
fi

#
# Restore database
#
echo "$(date +"%H:%M:%S"): Dropping old Nextcloud DB..."

if [ "${databaseSystem,,}" = "mysql" ] || [ "${databaseSystem,,}" = "mariadb" ]; then
    mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "DROP DATABASE ${nextcloudDatabase}"
elif [ "${databaseSystem,,}" = "postgresql" ]; then
	sudo -u postgres psql -c "DROP DATABASE ${nextcloudDatabase};"
fi

echo "Done"
echo

echo "$(date +"%H:%M:%S"): Creating new DB for Nextcloud..."

if [ "${databaseSystem,,}" = "mysql" ] || [ "${databaseSystem,,}" = "mariadb" ]; then
    if [ ! -z "${dbNoMultibyte+x}" ] && [ "${dbNoMultibyte}" = true ] ; then
        # Database from the backup DOES NOT use UTF8 with multibyte support (e.g. for emoijs in filenames)
        mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase}"
    else
        # Database from the backup uses UTF8 with multibyte support (e.g. for emoijs in filenames)
        mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
    fi
elif [ "${databaseSystem,,}" = "postgresql" ] || [ "${databaseSystem,,}" = "pgsql" ]; then
    sudo -u postgres psql -c "CREATE DATABASE ${nextcloudDatabase} WITH OWNER ${dbUser} TEMPLATE template0 ENCODING \"UNICODE\";"
fi

echo "Done"
echo

echo "$(date +"%H:%M:%S"): Restoring backup DB..."

if [ "${databaseSystem,,}" = "mysql" ] || [ "${databaseSystem,,}" = "mariadb" ]; then
	mysql -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
elif [ "${databaseSystem,,}" = "postgresql" ] || [ "${databaseSystem,,}" = "pgsql" ]; then
	sudo -u postgres psql "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
fi

echo "Done"
echo

#
# Start web server
#
echo "$(date +"%H:%M:%S"): Starting web server..."
systemctl start "${webserverServiceName}"
echo "Done"
echo

#
# Set directory permissions
#
echo "$(date +"%H:%M:%S"): Setting directory permissions..."
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudFileDir}"
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudDataDir}"

if [ ! -z "${nextcloudLocalExternalDataDir+x}" ] ; then
    chown -R "${webserverUser}":"${webserverUser}" "${nextcloudLocalExternalDataDir}"
fi

echo "Done"
echo

#
# Disbale maintenance mode
#
echo "$(date +"%H:%M:%S"): Switching off maintenance mode..."
sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:mode --off
echo "Done"
echo

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "$(date +"%H:%M:%S"): Updating the system data-fingerprint..."
sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:data-fingerprint
echo "Done"
echo

echo
echo "DONE!"
echo "$(date +"%H:%M:%S"): Backup ${restore} successfully restored."