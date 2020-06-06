#!/bin/bash

#
# Pre defined variables
#
backupMainDir='/media/hdd/nextcloud_backup'
nextcloudFileDir='/var/www/nextcloud'
webserverUser='www-data'

#
# Gather information
#
read -p "In which directory the backups should be saved (default: ${backupMainDir}). Enter a directory or press ENTER if the backup directory should be ${backupMainDir}: " BACKUPMAINDIR

[ -z "$BACKUPMAINDIR" ] ||  backupMainDir=$BACKUPMAINDIR

read -p "Enter the path to the Nextcloud file directory (usually ${nextcloudFileDir}). Enter a directory or press ENTER if the file directory is ${nextcloudFileDir}: " NEXTCLOUDFILEDIRECTORY

[ -z "$NEXTCLOUDFILEDIRECTORY" ] ||  nextcloudFileDir=$NEXTCLOUDFILEDIRECTORY

read -p "Enter the webserver user (usually ${webserverUser}). Enter an new user or press ENTER if the webserver user is ${webserverUser}: " WEBSERVERUSER

[ -z "$WEBSERVERUSER" ] ||  webserverUser=$WEBSERVERUSER

echo ""
echo ""
echo "Backup directory: ${backupMainDir}"
echo "Nextcloud file directory: ${nextcloudFileDir}"
echo "Webserver user: ${webserverUser}"
echo ""
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
# Read data from OCC and write to backup/restore scripts.
#

echo ""
echo ""
echo "Modifying NextcloudBackup.sh and NextcloudRestore.sh to match your installation..."
echo ""

# Backup main dir
sed -i "s@^    backupMainDir.*@    backupMainDir='$backupMainDir'@" ./NextcloudBackup.sh
sed -i "s@^    backupMainDir.*@    backupMainDir='$backupMainDir'@" ./NextcloudRestore.sh

# Nextcloud file dir
sed -i "s@^nextcloudFileDir.*@nextcloudFileDir='$nextcloudFileDir'@" ./NextcloudBackup.sh
sed -i "s@^nextcloudFileDir.*@nextcloudFileDir='$nextcloudFileDir'@" ./NextcloudRestore.sh

# Nextcloud data dir
nextcloudDataDir=$(occ_get datadirectory)

sed -i "s@^nextcloudDataDir=.*@nextcloudDataDir='$nextcloudDataDir'@" ./NextcloudBackup.sh
sed -i "s@^nextcloudDataDir=.*@nextcloudDataDir='$nextcloudDataDir'@" ./NextcloudRestore.sh

# Webserver service name

# Webserver user
sed -i "s/^webserverUser.*/webserverUser='$webserverUser'/" ./NextcloudBackup.sh
sed -i "s/^webserverUser.*/webserverUser='$webserverUser'/" ./NextcloudRestore.sh

# Database system
databaseSystem=$(occ_get dbtype)

sed -i "s/^databaseSystem.*/databaseSystem='$databaseSystem'/" ./NextcloudBackup.sh
sed -i "s/^databaseSystem.*/databaseSystem='$databaseSystem'/" ./NextcloudRestore.sh

# Database
nextcloudDatabase=$(occ_get dbname)

sed -i "s/^nextcloudDatabase.*/nextcloudDatabase='$nextcloudDatabase'/" ./NextcloudBackup.sh
sed -i "s/^nextcloudDatabase.*/nextcloudDatabase='$nextcloudDatabase'/" ./NextcloudRestore.sh

# Database user
dbUser=$(occ_get dbuser)

sed -i "s/^dbUser.*/dbUser='$dbUser'/" ./NextcloudBackup.sh
sed -i "s/^dbUser.*/dbUser='$dbUser'/" ./NextcloudRestore.sh

# Database password
dbPassword=$(occ_get dbpassword)

sed -i "s/^dbPassword.*/dbPassword='$dbPassword'/" ./NextcloudBackup.sh
sed -i "s/^dbPassword.*/dbPassword='$dbPassword'/" ./NextcloudRestore.sh

echo ""
echo "Done!"
echo ""
echo ""
echo "IMPORTANT: Please check NextcloudBackup.sh and NextcloudRestore.sh if all variables were set correctly BEFORE running these scripts!"
echo ""
echo ""