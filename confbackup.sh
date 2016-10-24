#!/bin/bash
# Description: Create a file based backup of the Confluence home and a database dump
# Author: q4p14

# Confluence variables
CONFUSR=confluence
CONFDIR=/opt/atlassian/confluence
CONFHOME=/var/atlassian/application-data/confluence
CONFDB=conf

# Local variables
TARGETDIR=/tmp
LOGDIR=/var/log

# Just get the date in the desired format (no symbols that must be escaped)
function today {
  date +%a%_d-%m-%y_%H-%M-%S
}

# This will be used to create a unique working directory
TODAY=$(today)

function cleanup {
  echo "$(today): Recieved signal to stop, cleaning backup direcotry structure" >> $LOGDIR/confbackup.log
  rm -rf $TARGETDIR/confbackup/$TODAY
  su -c "$CONFDIR/bin/startup.sh" $CONFUSR

  if [ ! -e "$CONFDIR/work/catalina.pid" ]; then
    echo "$(today): Can't restart Confluence process" >> $LOGDIR/confbackup.log
  fi
}

#Create the working directory for the backup, if it doesn't already exists
if [ ! -e $TARGETDIR/confbackup/$TODAY ]; then
        mkdir -p $TARGETDIR/confbackup/$TODAY/db
        chown postgres:postgres $TARGETDIR/confbackup/$TODAY/db
      else
        echo "$(today): Can't create backup directory $TARGETDIR/confbackup/$TODAY, does it already exist?" >> $LOGDIR/confbackup.log
        exit
fi
trap cleanup SIGTERM SIGHUP SIGINT

# Shutdown the Confluence service and wait as the service is pretty unresponsive
su -c "$CONFDIR/bin/shutdown.sh" $CONFUSR
trap cleanup SIGTERM SIGHUP SIGINT
sleep 1m
trap cleanup SIGTERM SIGHUP SIGINT

# If the Conluence service didn't shutdown properly, try the catalina stop script, which
# kills the Tomcat process
if [ -e "$CONFDIR/work/catalina.pid" ]; then
        su -c "$CONFDIR/bin/catalina.sh stop -force" $CONFUSR
        sleep 1m
fi
trap cleanup SIGTERM SIGHUP SIGINT

# If Confluenced isn't running anymore, backup the Confluence home directory:
# 1. Saving the Confluence home directory.
# 2. Create a directory for the postgres user to write the database dump into,
#    then backup the Confluence database.
# 3. Appending the existing archive and compressing it

if [ ! -e "$CONFDIR/work/catalina.pid" ]; then
        tar -cf "$TARGETDIR/confbackup/$TODAY/conf.tar" $CONFHOME
        su -c "pg_dump conf > $TARGETDIR/confbackup//$TODAY/db/conf_dump.sql" postgres
        tar -rf "$TARGETDIR/confbackup/$TODAY/conf.tar" $TARGETDIR/confbackup/$TODAY/db/conf_dump.sql
        gzip -9 "$TARGETDIR/confbackup/$TODAY/conf.tar"
      else
        echo "$(today): Couldn't stop Confluence/Tomcat process" >> $LOGDIR/confbackup.log
fi
trap cleanup SIGTERM SIGHUP SIGINT

# Restart Tomcat and the Confluence service
su -c "$CONFDIR/bin/startup.sh" $CONFUSR
