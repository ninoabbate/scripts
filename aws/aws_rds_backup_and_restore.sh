#!/bin/bash
#
# Author: Antonino Abbate
# 
# This script can be used to take a backup (snapshot) or to restore a snapshot of a RDS instance
# NOTE: The restored instance can't be named the same as the current running RDS instance
# 
# Requirements:
# aws-cli
#
# Usage:
# ./aws_rds_backup_and_restore.sh <profile> <instance name> <backup|restore>

PROFILE=$1
INSTANCE=$2
OPERATION=$3
NOW=$(date +%Y-%m-%d-%H-%M-%S)

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


#############################
#    Print script usage     #
#############################

function usage {
  echo "$0 - Script used to execute a RDS instance backup or a RDS instance restore "
  echo ""
  echo "Usage:    $0 <RDS_instance> <backup|restore>"
  echo ""
  echo ""
  echo "EXAMPLE:  $0 <RDS_instance> backup "
  echo "  = This will take a snapshot of the RDS instance"
  echo ""
  echo "EXAMPLE:  $0 <RDS_instance> restore "
  echo "  = This will restore the RDS instance from the latest snapshot"
  echo ""
}

###################
# take a snapshot #
###################

function backup {
  CUSTOMIDF="$(echo "$INSTANCE"-snapshot-"$NOW")"
  aws rds create-db-snapshot --region "$i" --profile "$PROFILE" --db-snapshot-identifier "$CUSTOMIDF" --db-instance-identifier "$INSTANCE"
  STATUS="$(aws rds describe-db-snapshots --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBSnapshots[-1].Status')"
  while [ "$STATUS" = "creating" ]
  do 
    sleep 1 
    echo -n '.' 
    STATUS="$(aws rds describe-db-snapshots --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBSnapshots[-1].Status')"
  done
  echo "Completed!"
  exit 0
}

#####################################
# get the latest snapshot available #
#####################################

function getlatestsnap {
  LATESTSNAP="$(aws rds describe-db-snapshots --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBSnapshots[-1].DBSnapshotIdentifier')"
  echo "Restoring "$LATESTSNAP" snapshot"
}

###########################
# get the db subnet group #
###########################

# Assumption: the DB subnet group name needs to be consistent on each region for all instances running in that region.

function getdbsg {
  DBSG="$(aws rds describe-db-instances --region "$i" --profile "$PROFILE" --query 'DBInstances[*].DBSubnetGroup[].DBSubnetGroupName' | head -2 | tr -d '[",' | tail -1 | sed -e 's/^[[:space:]]*//')"
}

########################
# get the new endpoint #
########################

function getendpoint {
  NEWENDPOINT="$(aws rds describe-db-instances --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBInstances[*].Endpoint[].Address')"
}

########################
# restore the snapshot #
########################

function restore {
  getlatestsnap
  getdbsg
  aws rds restore-db-instance-from-db-snapshot --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --db-snapshot-identifier "$LATESTSNAP" --db-subnet-group-name "$DBSG"
  STATUS="$(aws rds describe-db-instances --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBInstances[*].DBInstanceStatus')"
  while [ "$STATUS" = "creating" ]
  do 
    sleep 1 
    echo -n '.' 
    STATUS="$(aws rds describe-db-instances --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBInstances[*].DBInstanceStatus')"
  done
  echo "Completed!"
  echo "The new RDS instance "$INSTANCE" in "$i" is "$STATUS""
  getendpoint
  echo "The new RDS instance endpoint is "$NEWENDPOINT""
  exit 0
}

#########
# main  #
#########

case "$OPERATION" in
  backup|restore)
    if [ ${OPERATION} == 'backup' ]; then
      echo "The backup of "$INSTANCE" RDS instance is starting now"
      for i in "${REGIONS[@]}"; do  
        inst="$(aws rds describe-db-instances --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBInstances[*].DBInstanceStatus' 2>&1)"
        if [ "$inst" = "available" ]; then
          backup
        fi
      done
      echo "We haven't found any running RDS instance named "$INSTANCE", exiting now"
    else
      echo "The restore of lastest backup of "$INSTANCE" RDS instance will start now"
      read -r -p "Do you want to continue? [y/N] " response
      if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        for i in "${REGIONS[@]}"; do
          SNAPSTATUS="$(aws rds describe-db-snapshots --region "$i" --db-instance-identifier "$INSTANCE" --output text --query 'DBSnapshots[-1].Status')"
          if [ "$SNAPSTATUS" = "available" ]; then
            inst="$(aws rds describe-db-instances --region "$i" --profile "$PROFILE" --db-instance-identifier "$INSTANCE" --output text --query 'DBInstances[*].DBInstanceStatus' 2>&1)"
            if [ "$inst" = "available" ]; then
              echo "The RDS instance "$INSTANCE" is still running, please delete it before restoring the backup"
              exit 0
            else
              restore
            fi
          fi
        done
        echo "We haven't found any snapshot of "$INSTANCE" RDS instance, exiting now"
      else
        echo 'Aborted'
        exit 0
      fi
    fi
    ;;
  *)
    usage
    exit 0
    ;;
esac
