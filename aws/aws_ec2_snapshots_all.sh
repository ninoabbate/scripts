#!/bin/bash
#
# Author: Antonino Abbate
# 
# This script creates a snapshot of all EBS volumes in all regions in a profile.
# This script will remove all snapshots older than 2 weeks but only if there are more than 2 snapshosts of its volume.
# 
# Requirements:
# aws-cli, jq
#
# Usage:
# ./aws_ec2_snapshots.sh <profile>

PROFILE=$1
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
	aws ec2 describe-instances --region "$i" --profile "$PROFILE" --output text --query 'Reservations[*].Instances[*].InstanceId'
}

function getinstancename {
	INSTANCENAME="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-ids "$id" --output text --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value[]')"
}

function getvolumeid {
	VOLUMEID="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-ids "$id" --output text --query  'Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId')"
}

function createsnapshot {
	INSTANCESTATE="$(aws ec2 describe-instances --region "$i" --profile "$PROFILE" --instance-ids "$id" --output text --query 'Reservations[].Instances[].State[].Name')"
	# Check if the instance is running
	if [ $INSTANCESTATE = "terminated" ] || [ $INSTANCESTATE = "stopped" ]; then
		echo "$INSTANCENAME" 'is not a running instance'
	else
		Volumes=($VOLUMEID)
		for volID in "${Volumes[@]}"; do
			DEVICENAME="$(aws ec2 describe-volumes --region "$i" --profile "$PROFILE" --volume-ids "$volID" --output text --query 'Volumes[].Attachments[].Device')"
			echo -n 'Now creating a snapshot for' "$INSTANCENAME" "$DEVICENAME"
			DESC=$(echo "$INSTANCENAME" "$DEVICENAME" "$NOW")
			SNAPSHOT="$(aws ec2 create-snapshot --region "$i" --profile "$PROFILE" --volume-id "$volID" --description "$DESC" | jq '.SnapshotId')"
	
			# Get the snapshot id
			SNAPSHOTID=$(echo "${SNAPSHOT//\"}") 
			SNAPSHOTID=$(echo "${SNAPSHOTID//\,}")

			# Tag the name of this snapshot
			TAG=$(echo "$INSTANCENAME" "$DEVICENAME")
			aws ec2 create-tags --region "$i" --profile "$PROFILE" --resources "$SNAPSHOTID" --tags Key=Name,Value="$TAG"

			STATUS="$(aws ec2 describe-snapshots --region "$i" --profile "$PROFILE" --snapshot-ids "$SNAPSHOTID" --output text --query 'Snapshots[].State')"
	
			# Check if it is still processing the snapshot
			while [ $STATUS = "pending" ]; do 
  				sleep 1 
  				echo -n '.' 
  				STATUS="$(aws ec2 describe-snapshots --region "$i" --profile "$PROFILE" --snapshot-ids "$SNAPSHOTID" --output text --query 'Snapshots[].State')"
			done
			echo ' '"$STATUS"
		done
	fi
}

function doit {
	INSTANCEID=$(getinstanceid)
	INSTANCEIDs=($INSTANCEID)
	for id in "${INSTANCEIDs[@]}"; do
		getinstancename 
		getvolumeid 
		createsnapshot
	done 
}

function removeolder {
	CURRENTSNAPS="$(aws ec2 describe-snapshots --region "$i" --profile "$PROFILE" --owner-ids self --output text --query 'Snapshots[].SnapshotId')"
	SNAPS=($CURRENTSNAPS)
	# only for OSX date
	#TWOWEEKSAGO=$(echo `date -v-2w +%F`)
	TWOWEEKSAGO=$(date -d ""$NOW" -14 days" +%Y-%m-%d)
	for snap in "${SNAPS[@]}"; do
 		STARTDATE="$(aws ec2 describe-snapshots --region "$i" --profile "$PROFILE" --owner-ids self --snapshot-ids "$snap" --output text --query 'Snapshots[].StartTime')"
 		STARTDATE=$(date -d "$STARTDATE" +%Y-%m-%d)
 		SNAPVOLUME="$(aws ec2 describe-snapshots --region "$i" --profile "$PROFILE" --owner-ids self --snapshot-ids "$snap" --output text --query 'Snapshots[].VolumeId')"
 		if [ "$STARTDATE" \< "$TWOWEEKSAGO" ]; then
 			# verify if there are more than 2 snapshot of a volume
 			SNAPCOUNT="$(aws ec2 describe-snapshots --region "$i" --profile "$PROFILE" --owner-ids self | grep "$SNAPVOLUME" | wc -l)"
 			MAXSNAPS=2
 			if [ "$SNAPCOUNT" -gt "$MAXSNAPS" ]; then
 				aws ec2 delete-snapshot --region "$i" --profile "$PROFILE" --snapshot-id "$snap"
 			else
 				echo "$snap" 'will not be deleted'
			fi
		else
 			echo "$snap" 'will not be deleted'
		fi
	done
}

for i in "${REGIONS[@]}"; do   
	doit
	removeolder
done
