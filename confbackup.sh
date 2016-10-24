#!/bin/bash

# Confluence variables
CONFUSR=confluence
CONFDIR=/opt/atlassian/confluence
CONFHOME=/var/atlassian/application-data/confluence
CONFDB=conf

# Local variables
TODAY=$(date +%a%_d-%m-%y_%H-%M-%S)
TARGETDIR=/root
LOGDIR=/var/log

# Shutdown the Confluence service and wait as the service is pretty unresponsive
su -c "$CONFDIR/bin/shutdown.sh" $CONFUSR
sleep 1m

# If the Conluence service didn't shutdown properly, try the catalina stop script, which
# kills the Tomcat process
if [ -e "$CONFDIR/work/catalina.pid" ]; then
        su -c "$CONFDIR/bin/catalina.sh stop -force" $CONFUSR
        sleep 1m
fi

# If Confluenced isn't running anymore, backup the Confluence home directory:
# 1. Saving the Confluence home directory.
# 2. Create a directory for the postgres user to write the database dump into,
#    then backup the Confluence database.
# 3. Appending the existing archive and compressing it

if [ ! -e "$CONFDIR/work/catalina.pid" ]; then
        tar -cf "$TARGETDIR/conf_$TODAY.tar" $CONFHOME

        mkdir /tmp/$TODAY
        chown postgres:postgres /tmp/$TODAY
        su -c "pg_dump conf > /tmp/$TODAY/conf_dump.sql" postgres

        tar -rf "$TARGETDIR/conf_$TODAY.tar" /tmp/$TODAY/conf_dump.sql
        gzip -9 "$TARGETDIR/conf_$TODAY.tar"

      else
        echo "$(date +%a%_d-%m-%y_%H-%M-%S): Couldn't stop Confluence/Tomcat process" >> $LOGDIR/confbackup.log
fi

# Restart Tomcat and the Confluence service
su -c "$CONFDIR/bin/startup.sh" $CONFUSR
