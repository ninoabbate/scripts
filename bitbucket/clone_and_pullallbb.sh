#!/bin/bash
#
# Author: Antonino Abbate
#
# This script clones and pulls all Bitbucket repositories in an organization where the user is a member. 
#
# Requirements:
# curl, jq
#
# USAGE:
# ./clone_and_pullallbb.sh
#
# Before executing the script fill these variables with your values:
#
# OWNER: is the organization username (value inside "values->owner->username" on /repositories endpoint) 
# BBUSER: is the Bitbucket username
# BBPASS: is the Bitbucket user password or the APP password

OWNER="organization"
BBUSER="username"
BBPASS="password"

REPOS=$(curl --user "$BBUSER":"$BBPASS" -X GET "https://api.bitbucket.org/2.0/repositories?pagelen=500&role=member" | jq '.values[] .name')

bbrepos=($REPOS)

# Clone all repos
for i in "${bbrepos[@]}" 
  do 
    repository=$(echo "${i//\"}")
    echo 
    echo Now cloning "$repository" repo
    echo
    git clone git@bitbucket.org:"$OWNER"/"$repository".git
  done

# Pull updates from repo
for i in "${bbrepos[@]}" 
  do 
    repository=$(echo "${i//\"}")
    echo 
    echo Now updating "$repository" repo
    echo
    (cd "$repository" && git pull)
  done
