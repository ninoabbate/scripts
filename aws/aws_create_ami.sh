#!/bin/bash
#
# Author: Antonino Abbate
# 
# This script creates a new AMI from a running EC2 instance
# 
# Requirements:
# aws-cli
#
# Usage:
# ./aws_create_ami.sh <profile> <instance name>

PROFILE=$1
INSTANCE=$2

# ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###
# Make sure to edit your aws cli configuration in order to define a default region, for example:
# ~/.aws/config
#
# [default]
# region = us-west-1
# 
# ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 

ALLREGIONS="$(aws ec2 describe-regions --query 'Regions[].{Name:RegionName}' --output text | tr -s [:space:] ' ' | tr -d '\n')"
IFS=' ' read -r -a REGIONS <<< "$ALLREGIONS"

# Set the date to current date in the following format "YYYY-MM-DD_HHMMSS"
NOW=$(date +%Y-%m-%d_%H%M%S)

echo
echo 'Creating an image of '"$INSTANCE"
sleep 1
echo 'PAY ATTENTION: When creating the new AMI, the instance will be restarted'

for i in "${REGIONS[@]}"; do
	# Get the Instance-ID
	INSTANCEID="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --filters "Name=tag:Name,Values=$2" --output text --query 'Reservations[*].Instances[*].InstanceId')"
	if [ "$INSTANCEID" ]; then
		# Create the new AMI using the defined naming convention 
		AMI="$(aws ec2 create-image --region "$i" --profile "$PROFILE" --instance-id "$INSTANCEID" --name "$INSTANCE"-"$NOW" --description "$INSTANCE"-"$NOW" --reboot --output text)"
		STATUS="$(aws ec2 describe-images --region "$i" --profile "$PROFILE" --image-ids "$AMI" --output text --query 'Images[].State')"
		while [ $STATUS = "pending" ]; do 
  			sleep 2
  			echo -n '.' 
  			STATUS="$(aws ec2 describe-images --region "$i" --profile "$PROFILE" --image-ids "$AMI" --output text --query 'Images[].State')"
		done
			echo ' new AMI created'
		exit
	else
		echo -n '.'
	fi
done
