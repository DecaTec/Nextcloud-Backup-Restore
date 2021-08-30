#!/bin/bash

#
# Bash script for restoring backups of Nextcloud.
#
# Version 2.1.3
#
# Usage:
#   - With backup directory specified in the script: ./NextcloudRestore.sh <BackupName> (e.g. ./NextcloudRestore.sh 20170910_132703)
#   - With backup directory specified by parameter: ./NextcloudRestore.sh <BackupName> <BackupDirectory> (e.g. ./NextcloudRestore.sh 20170910_132703 /media/hdd/nextcloud_backup)
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-18-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

# Variables
restore=$1
backupMainDir=$2

if [ -z "$backupMainDir" ]; then
	# TODO: The directory where you store the Nextcloud backups (when not specified by args)
    backupMainDir='/media/hdd/nextcloud_backup'
fi

echo "Backup directory: $backupMainDir"

# TODO: Set this to true, if the backup was created with compression enabled, otherwiese false.
useCompression=true

currentRestoreDir="${backupMainDir}/${restore}"

# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
nextcloudFileDir='/var/www/nextcloud'

# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located under Nextcloud's file directory (somewhere in the web root), the data directory should not be restored separately
nextcloudDataDir='/var/nextcloud_data'

# TODO: The directory of your Nextcloud's local external storage.
# Uncomment if you use local external storage.
#nextcloudLocalExternalDataDir='/var/nextcloud_external_data'

# TODO: The service name of the web server. Used to start/stop web server (e.g. 'systemctl start <webserverServiceName>')
webserverServiceName='nginx'

# TODO: Your web server user
webserverUser='www-data'

# TODO: The name of the database system (one of: mysql, mariadb, postgresql)
databaseSystem='mariadb'

# TODO: Your Nextcloud database name
nextcloudDatabase='nextcloud_db'

# TODO: Your Nextcloud database user
dbUser='nextcloud_db_user'

# TODO: The password of the Nextcloud database user
dbPassword='mYpAsSw0rd'

# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudBackup.sh script.
fileNameBackupFileDir='nextcloud-filedir.tar'
fileNameBackupDataDir='nextcloud-datadir.tar'

if [ "$useCompression" = true ] ; then
    fileNameBackupFileDir='nextcloud-filedir.tar.gz'
    fileNameBackupDataDir='nextcloud-datadir.tar.gz'
fi

# TODO: Uncomment if you use local external storage
#fileNameBackupExternalDataDir='nextcloud-external-datadir.tar'
#
#if [ "$useCompression" = true ] ; then
#    fileNameBackupExternalDataDir='nextcloud-external-datadir.tar.gz'
#fi

fileNameBackupDb='nextcloud-db.sql'

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

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
rm -r "${nextcloudFileDir}"
mkdir -p "${nextcloudFileDir}"
echo "Done"
echo

# Data directory
echo "$(date +"%H:%M:%S"): Deleting old Nextcloud data directory..."
rm -r "${nextcloudDataDir}"
mkdir -p "${nextcloudDataDir}"
echo "Done"
echo

# Local external storage
# TODO: Uncomment if you use local external storage
#echo "Deleting old Nextcloud local external storage directory..."
#rm -r "${nextcloudLocalExternalDataDir}"
#mkdir -p "${nextcloudLocalExternalDataDir}"
#echo "Done"
#echo

#
# Restore file and data directory
#

# File directory
echo "$(date +"%H:%M:%S"): Restoring Nextcloud file directory..."

if [ "$useCompression" = true ] ; then
    tar -I pigz -xmpf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"
else
    tar -xmpf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"
fi

echo "Done"
echo

# Data directory
echo "$(date +"%H:%M:%S"): Restoring Nextcloud data directory..."

if [ "$useCompression" = true ] ; then
    tar -I pigz -xmpf "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"
else
    tar -xmpf "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"
fi

echo "Done"
echo

# Local external storage
# TODO: Uncomment if you use local external storage
#echo "$(date +"%H:%M:%S"): Restoring Nextcloud data directory..."
#
#if [ "$useCompression" = true ] ; then
#    tar -I pigz -xmpf "${currentRestoreDir}/${fileNameBackupExternalDataDir}" -C "${nextcloudLocalExternalDataDir}"
#else
#    tar -xmpf "${currentRestoreDir}/${fileNameBackupExternalDataDir}" -C "${nextcloudLocalExternalDataDir}"
#fi
#
#echo "Done"
#echo

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
    # Use this if the databse from the backup uses UTF8 with multibyte support (e.g. for emoijs in filenames):
    mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
    # TODO: Use this if the database from the backup DOES NOT use UTF8 with multibyte support (e.g. for emoijs in filenames):
    #mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase}"
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
# TODO: Uncomment if you use local external storage
#chown -R "${webserverUser}":"${webserverUser}" "${nextcloudLocalExternalDataDir}"
echo "Done"
echo

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "$(date +"%H:%M:%S"): Updating the system data-fingerprint..."
sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:data-fingerprint
echo "Done"
echo

#
# Disbale maintenance mode
#
echo "$(date +"%H:%M:%S"): Switching off maintenance mode..."
sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:mode --off
echo "Done"
echo

echo
echo "DONE!"
echo "$(date +"%H:%M:%S"): Backup ${restore} successfully restored."