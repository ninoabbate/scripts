#!/bin/bash
#
# Author: Antonino Abbate
# 
# This script change the instance type of a running EC2 instance
# 
# Requirements:
# aws-cli
#
# Usage:
# ./aws_ec2_change_instance_type.sh <profile> <instance name> <instance type>

PROFILE=$1
INSTANCE=$2
INSTTYPE=$3

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

function stop_instance {
	# Stop the instance
	echo
	echo 'Stopping '"$INSTANCE"
	echo

	aws ec2 --region "$i" --profile "$PROFILE" stop-instances --instance-id "$INSTANCEID"

	STATE="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-id "$INSTANCEID" --output text --query 'Reservations[*].Instances[*].State.Name')"

	# Check if it's stopped
	while [ $STATE = "stopping" ]
	do 
  		sleep 1 
  		echo -n '.' 
  		STATE="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-id "$INSTANCEID" --output text --query 'Reservations[*].Instances[*].State.Name')"
	done
 
	echo "$STATE"
}

function change_type {
	# Change the instance type 
	echo
	echo 'The instance type will be changed to '$INSTTYPE

	aws ec2 modify-instance-attribute --region "$i" --profile "$PROFILE" --instance-id "$INSTANCEID" --instance-type "$INSTTYPE"
}

function start_instance {
	# Start the instance
	echo
	echo 'Starting '"$INSTANCE"
	echo

	aws ec2 --region "$i" --profile "$PROFILE" start-instances --instance-id "$INSTANCEID"

	STATE="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-id "$INSTANCEID" --output text --query 'Reservations[*].Instances[*].State.Name')"

	# Check if it's started
	while [ $STATE = "pending" ]
	do
  		sleep 1
  		echo -n '.'
  		STATE="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-id "$INSTANCEID" --output text --query 'Reservations[*].Instances[*].State.Name')"
	done

	echo "$STATE"
}

echo
echo 'The EC2 instance '"$INSTANCE" 'will be modified to' "$INSTTYPE"

echo 'PAY ATTENTION: When changing the instance type, the EC2 instance will be restarted'

read -r -p "Do you want to continue? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	for i in "${REGIONS[@]}"; do
		# Get the Instance-ID
		INSTANCEID="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --filters "Name=tag:Name,Values=$INSTANCE" --output text --query 'Reservations[*].Instances[*].InstanceId')"
		if [ "$INSTANCEID" ]; then

			# To change type of a running instance we need to perform these tasks:
			# 1- Stop the instance
			stop_instance
		
			# 2- Change the type
			change_type
		
			# 3- Start the instance
			start_instance
		fi
	done
else
    echo 'Aborted'
    exit 0
fi
