#!/bin/bash

# workaround for maven path issue
export PATH=$PATH:/opt/apache-maven-$MAVEN_VERSION/bin

#Hack for maven setup on cdh5-dev
update-ca-certificates -f

#Configure Hadoop
curl -s http://resources.prod.factual.com/services/hadoop/cdh5/scripts/get_configs.sh | bash

#Setup Kerberos credentials for Hadoop
curl -s https://keyserver.prod.factual.com/scarecrow/scarecrow-services.scarecrow-services.keytab.sec  | openssl des3 -d -k "$KEYTAB_PASSPHRASE" > /etc/krb5.keytab
kinit -l 24h -kt /etc/krb5.keytab scarecrow-services@FACTUAL.COM

#Setup github credentials
curl -s  https://keyserver.prod.factual.com/scarecrow/scarecrow-services.deploy.sec | openssl des3 -d -k "$GITHUB_KEY_PASSPHRASE" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
curl -s http://resources.prod.factual.com/services/github/known_hosts > ~/.ssh/known_hosts

#Checkout from github
git clone git@github.com:Factual/scarecrow-lucene-services
cd /scarecrow-lucene-services
git checkout $SC_SERVICES_BRANCH

#Build
mvn clean package -Dmaven.test.skip=true

#Setup
mkdir -p /var/local/lucene_indexes/
echo "{}" > /var/local/lucene_indexes/INDEXES.json

#Set locale
export LANG=en_US.UTF-8
export LANGUAGE=en_US:
export LC_CTYPE="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_MONETARY="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_PAPER="en_US.UTF-8"
export LC_NAME="en_US.UTF-8"
export LC_ADDRESS="en_US.UTF-8"
export LC_TELEPHONE="en_US.UTF-8"
export LC_MEASUREMENT="en_US.UTF-8"
export LC_IDENTIFICATION="en_US.UTF-8"

#Copy HDFS input file
mktemp
LOCAL_FILE=/tmp/data.json
hadoop fs -copyToLocal $INPUT_FILE $LOCAL_FILE

#Run
export YARN_HEAPSIZE=2048

JAR=./target/scarecrow-lucene-services-app.jar
MAIN_CLASS=com.factual.lucene.scarecrow.io.indexing.FileIndexer
if [[ -z $CASE_SENSITIVE ]] || [[ -z $LOCALE ]]; then
    yarn jar $JAR $MAIN_CLASS index_type=$INDEX_TYPE input_file=$LOCAL_FILE index_name=$INDEX_NAME scope=$SCOPE num_threads=$NTHREADS
else
    yarn jar $JAR $MAIN_CLASS index_type=$INDEX_TYPE input_file=$LOCAL_FILE index_name=$INDEX_NAME scope=$SCOPE num_threads=$NTHREADS case_sensitive=$CASE_SENSITIVE locale=$LOCALE
fi
