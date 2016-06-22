#!/bin/bash

DATABASE=lucene_indexes
HDFS_BACKUP=/apps/extract/lib/scarecrow-index-server-db-backup/db.sql
LOCAL_BACKUP=/scarecrow-lucene-services/backup/db.sql

#Configure Hadoop
echo "CONFIGURING HADOOP!"
curl -s http://resources.prod.factual.com/services/hadoop/cdh5/scripts/get_configs.sh | bash

#Setup Kerberos credentials for Hadoop
curl -s https://keyserver.prod.factual.com/scarecrow/scarecrow-services.scarecrow-services.keytab.sec  | openssl des3 -d -k "$KEYTAB_PASSPHRASE" > /etc/krb5.keytab
kinit -l 24h -kt /etc/krb5.keytab scarecrow-services@FACTUAL.COM

#Setup cron
rsyslogd
cron
touch /var/log/cron.log

#Setup github credentials
curl -s  https://keyserver.prod.factual.com/scarecrow/scarecrow-services.deploy.sec | openssl des3 -d -k "$GITHUB_KEY_PASSPHRASE" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
curl -s http://resources.prod.factual.com/services/github/known_hosts > ~/.ssh/known_hosts

#Create Database
sudo -u postgres createdb $DATABASE

#Create table and triggers
git clone git@github.com:Factual/scarecrow-lucene-services
cd /scarecrow-lucene-services
git checkout $SC_SERVICES_BRANCH

rm -f $LOCAL_BACKUP
hadoop fs -copyToLocal $HDFS_BACKUP $LOCAL_BACKUP
sudo -u postgres psql -U postgres -d $DATABASE -a -f $LOCAL_BACKUP

# start cron
if [ "$BACKUP_DB" == "true" ]
then
  chmod +x backup/backup.sh
  echo -e "* * * * * /bin/bash /scarecrow-lucene-services/backup/backup.sh\n" > /tmp/cron;
  crontab /tmp/cron;
fi
