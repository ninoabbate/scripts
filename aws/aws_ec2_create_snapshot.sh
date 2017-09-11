#!/bin/bash
#
# Author: Antonino Abbate
# 
# This script creates a snapshot of all EBS volumes attached to an instance.
# This script will remove all snapshots older than 2 weeks, but only if there are more than 2 snapshosts of its volume.
# 
# Requirements:
# aws-cli, jq
#
# Usage:
# ./aws_ec2_create_snapshots.sh <profile> <ec2 instance name>

PROFILE=$1
INSTANCENAME=$2
NOW=$(date +%Y-%m-%d)

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

function getinstanceid {
	for i in "${REGIONS[@]}"; do  
		# Get the Instance-ID
		ID="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --filters "Name=tag:Name,Values=$INSTANCENAME" --output text --query 'Reservations[*].Instances[*].InstanceId')"
		if [ -n "$ID" ]; then
			REG="$i"
			INSTANCEID="$ID"
		fi
	done
}

function getvolumeid {
	VOLUMEID="$(aws ec2 describe-instances --region "$REG" --profile "$PROFILE" --instance-ids "$INSTANCEID" --output text --query  'Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId')"
}

function createsnapshot {
	INSTANCESTATE="$(aws ec2 describe-instances --region "$REG" --profile "$PROFILE" --instance-ids "$INSTANCEID" --output text --query 'Reservations[].Instances[].State[].Name')"
	# Check if the instance is running
	if [ $INSTANCESTATE = "terminated" ] || [ $INSTANCESTATE = "stopped" ]; then
		echo "$INSTANCENAME" 'is not a running instance'
	else
		Volumes=($VOLUMEID)
		for volID in "${Volumes[@]}"; do
			DEVICENAME="$(aws ec2 describe-volumes --region "$REG" --profile "$PROFILE" --volume-ids "$volID" --output text --query 'Volumes[].Attachments[].Device')"
			echo -n 'Now creating a snapshot for' "$INSTANCENAME" "$DEVICENAME"
			DESC=$(echo "$INSTANCENAME" "$DEVICENAME" "$NOW")
			SNAPSHOT="$(aws ec2 create-snapshot --region "$REG" --profile "$PROFILE" --volume-id "$volID" --description "$DESC" | jq '.SnapshotId')"
	
			# Get the snapshot id
			SNAPSHOTID=$(echo "${SNAPSHOT//\"}") 
			SNAPSHOTID=$(echo "${SNAPSHOTID//\,}")

			# Tag the name of this snapshot
			TAG=$(echo "$INSTANCENAME" "$DEVICENAME")
			aws ec2 create-tags --region "$REG" --profile "$PROFILE" --resources "$SNAPSHOTID" --tags Key=Name,Value="$TAG"

			STATUS="$(aws ec2 describe-snapshots --region "$REG" --profile "$PROFILE" --snapshot-ids "$SNAPSHOTID" --output text --query 'Snapshots[].State')"
	
			# Check if it is still processing the snapshot
			while [ $STATUS = "pending" ]; do 
  				sleep 1 
  				echo -n '.' 
  				STATUS="$(aws ec2 describe-snapshots --region "$REG" --profile "$PROFILE" --snapshot-ids "$SNAPSHOTID" --output text --query 'Snapshots[].State')"
			done
			echo ' '"$STATUS"
		done
	fi
}

function removeolder {
	CURRENTSNAPS="$(aws ec2 describe-snapshots --region "$REG" --profile "$PROFILE" --filters  Name=volume-id,Values="$VOLUMEID" --output text --query 'Snapshots[].SnapshotId')"
	SNAPS=($CURRENTSNAPS)
	OS=$(uname -a | awk '{print $1}')
	if [ $OS = "Darwin" ]; then
		# If the operating system where this script runs is OSX
		TWOWEEKSAGO=$(date -v-2w +%F)
	else
		TWOWEEKSAGO=$(date -d ""$NOW" -14 days" +%Y-%m-%d)
	fi
	for snap in "${SNAPS[@]}"; do
		STARTDATE="$(aws ec2 describe-snapshots --region "$REG" --profile "$PROFILE" --owner-ids self --snapshot-ids "$snap" --output text --query 'Snapshots[].StartTime')"
 		STARTDATE="$(echo $STARTDATE | cut -f1 -d"T")"
 		SNAPVOLUME="$(aws ec2 describe-snapshots --region "$REG" --profile "$PROFILE" --owner-ids self --snapshot-ids "$snap" --output text --query 'Snapshots[].VolumeId')"
 		if [ "$STARTDATE" \< "$TWOWEEKSAGO" ]; then
 			# verify if there are more than 2 snapshot of a volume
 			SNAPCOUNT="$(aws ec2 describe-snapshots --region "$REG" --profile "$PROFILE" --owner-ids self | grep "$SNAPVOLUME" | wc -l)"
 			MAXSNAPS=2
 			if [ "$SNAPCOUNT" -gt "$MAXSNAPS" ]; then
 				aws ec2 delete-snapshot --region "$REG" --profile "$PROFILE" --snapshot-id "$snap"
 			else
 				echo "$snap" 'will not be deleted'
			fi
		else
 			echo "$snap" 'will not be deleted'
		fi
	done
}

# Do the work! 
getinstanceid
getvolumeid 
createsnapshot
removeolder
