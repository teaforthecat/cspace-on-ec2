#!/bin/bash -ex
#
# cspace builder
#
# Create an new ec2 instance and call exec ./ec2install on it 
# The server will be accessible on the default port (8180)



# This script has been adapted from from:
#    https://github.com/alestic/alestic-git.git
#

# Be sure to have declared ec2 credentials in env vars
# such as:
# export EC2_KEYPAIR=***
# export EC2_URL=https://ec2.us-east-1.amazonaws.com
# export EC2_PRIVATE_KEY=path-to-file
# export EC2_CERT=path-to-file
# export JAVA_HOME=/usr/lib/jvm/java-6-openjdk/
# export EC2_ACCESS_KEY_ID=***
# export EC2_SECRET_ACCESS_KEY=***

# This assumes you have uploaded to EC2 an ssh key with your username
# as described in http://alestic.com/2010/10/ec2-ssh-keys
keypair="$USER"

# Wherever you keep your AWS credentials
awscredentials=$(echo ~/.ec2/cacert.pem ~/.ec2/cakey.pem)

# Region
region="us-east-1"

# Architecture
arch="amd64"

instance_type="m1.large"

# Ubuntu release
codename="natty"

# Command line options
while [ $# -gt 0 ]; do
  case $1 in
    --keypair)       keypair=$2;       shift 2 ;;
    --region)        region=$2;        shift 2 ;;
    --arch)          arch=$2;          shift 2 ;;
    --codename)      codename=$2;      shift 2 ;;
    *)               echo "$0: Unrecognized option: $1" >&2; exit 1;
  esac
done

export EC2_URL=http://ec2.$region.amazonaws.com
zone=${region}a

amisurl=http://uec-images.ubuntu.com/query/$codename/server/released.current.txt
amiid=$(wget -qO- $amisurl | egrep "ebs.$arch.$region.*paravirtual" | cut -f8)


instance_id=$(                                       \
  ec2-run-instances                                  \
    --instance-type "$instance_type"                 \
    --availability-zone "$zone"                      \
    --key "$keypair"                                 \
    "$amiid" |
  egrep ^INSTANCE | cut -f2)
echo "$codename $region $arch2 instance_id=$instance_id"

# Add an instance tag
ec2-create-tags --tag Name="Collection Space 2.0" $instance_id

# Wait for the instance to start running and get the IP address
while host=$(ec2-describe-instances "$instance_id" |
  egrep "^INSTANCE.*running" | cut -f17); test -z "$host";
    do sleep 30; done
echo "$codename $region $arch2 host=$host"
perl -MIO::Socket::INET -e "
  until(new IO::Socket::INET('$host:22')){sleep 1}"
sleep 10

# Copy build script and env variables to the instance
# TODO: we should be able to copy both files at once
rsync                       \
  --rsh="ssh -o 'StrictHostKeyChecking false'" \
  --rsync-path="sudo rsync" \
  ec2install.sh  \
  ubuntu@$host:

rsync                       \
  --rsh="ssh -o 'StrictHostKeyChecking false'" \
  --rsync-path="sudo rsync" \
  cspace-vars \
  ubuntu@$host:


time ssh ubuntu@$host ./ec2install.sh
