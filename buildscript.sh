#!/bin/bash -ex
#!/bin/bash -ex
#
# cspace builder
#
# Build CollectionSpace Server AMIs for all regions, architectures
# taken from alestic-git-build-ami-all
#

# This assumes you have uploaded to EC2 an ssh key with your username
# as described in http://alestic.com/2010/10/ec2-ssh-keys
keypair="$USER"

# Wherever you keep your AWS credentials
awscredentials=$(echo ~/.ec2/cacert.pem ~/.ec2/cakey.pem)

# Brand used in AMI name and description
brand="cspace2"

# Regions (separate by spaces)
# regions=$(ec2-describe-regions | cut -f2 | sort -r)
regions="us-east-1"

# Architectures (separate by spaces)
architectures="amd64"

# Size of AMI file system
size=8 # GB

# Ubuntu releases (separate by spaces)
# codenames="oneiric"
codenames="natty"

# Timestamp for AMI names
now=$(date -u +%Y%m%d-%H%M)

# Command line options
while [ $# -gt 0 ]; do
  case $1 in
    --keypair)       keypair=$2;       shift 2 ;;
    --brand)         brand=$2;         shift 2 ;;
    --regions)       regions=$2;       shift 2 ;;
    --architectures) architectures=$2; shift 2 ;;
    --size)          size=$2;          shift 2 ;;
    --codenames)     codenames=$2;     shift 2 ;;
    --now)           now=$2;           shift 2 ;;
    *)               echo "$0: Unrecognized option: $1" >&2; exit 1;
  esac
done

for codename in $codenames; do
  for region in $regions; do
    export EC2_URL=http://ec2.$region.amazonaws.com
    zone=${region}a
    for arch2 in $architectures; do

      amisurl=http://uec-images.ubuntu.com/query/$codename/server/released.current.txt
      amiid=$(wget -qO- $amisurl | egrep "ebs.$arch2.$region.*paravirtual" | cut -f8)

      # Start an instance of the desired architecture in the desired region
      if [ $arch2 = 'i386' ]; then
        instance_type=c1.medium
      else
        instance_type=m1.large
      fi

      instance_id=$(                                       \
        ec2-run-instances                                  \
          --instance-type "$instance_type"                 \
          --availability-zone "$zone"                      \
          --key "$keypair"                                 \
          --instance-initiated-shutdown-behavior terminate \
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

      # Copy AMI build script and AWS credentials to the instance
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

      # Run the AMI builder on the instance
      # time ssh ubuntu@$host        \
      #   /mnt/alestic-git-build-ami \
      #     --codename $codename     \
      #     --brand "$brand"         \
      #     --now "$now"         2>&1 |
      # tee alestic-git-$codename-$region-$arch2.log

      # Terminate the temporary AMI builder instance
      # ec2-terminate-instances $instance_id

    done
  done
done
