#!/bin/bash -ex
# This script is meant to run on a new ec2 instance of ubuntu-natty
# teaforthecat@gmail.com

sudo apt-get update;

sudo apt-get install -y --force-yes maven2 ant postgresql imagemagick subversion ftp;

sudo -u postgres createlang plpgsql template1;

sudo -u postgres createuser catalina --superuser;

sudo -u postgres createdb catalina;

sudo -u postgres psql -c "ALTER USER catalina WITH PASSWORD 'nuxeo'";

sudo mv /etc/postgresql/8.4/main/pg_hba.conf /etc/postgresql/8.4/main/pg_hba.conf.archive;

cat /etc/postgresql/8.4/main/pg_hba.conf | sed /^local.*ident$/s/ident/trust/ > hba;

sudo mv -f hba /etc/postgresql/8.4/main/pg_hba.conf;

wget -q ftp://source.collectionspace.org/pub/collectionspace/releases/2.0/apache-tomcat-6.0.33-2011-12-15.tar.gz;

tar zxvof apache-tomcat-6.0.33-2011-12-15.tar.gz;

chmod u+x apache-tomcat-6.0.33/bin/*.sh;

sudo mv apache-tomcat-6.0.33 /usr/local/share/;

rm apache-tomcat-6.0.33-2011-12-15.tar.gz;

svn co -q --force --no-auth-cache --non-interactive --trust-server-cert https://source.collectionspace.org/collection-space/src/services/tags/v2.0/;

cd v2.0/;

source ~/cspace-vars;

mvn clean install -DskipTests;

ant undeploy deploy create_db import;

sudo ln -s /usr/local/share/apache-tomcat-6.0.33/bin/startup.sh /etc/init.d/cspace-startup;

sudo update-rc.d cspace-startup defaults;

sudo /etc/init.d/cspace-startup;

echo "done with install";