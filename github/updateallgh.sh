#!/bin/bash
#
# Author: Antonino Abbate
#
# This script pull all GitHub repositories in an organization where the user is a member. 
#
# Requirements:
# curl
#
# USAGE:
# ./updateallgh.sh
#
# Before executing the script fill these variables with your values:
#
# ORG: is the organization name
# GHTOKEN: is the GitHub token

ORG="organization"
GHTOKEN="token"

REPOS=$(curl -X GET "https://api.github.com/orgs/"$ORG"/repos?access_token="$GHTOKEN"&per_page=500" \
      | grep name | grep -v "full_name" | grep -v "labels_url" | grep -v "description" | awk '{print $2}')

ghrepos=($REPOS)

for i in "${ghrepos[@]}" 
  do 
    repository=$(echo "${i//\"}")
    repository=$(echo "${repository//\,}")
    echo 
    echo Now updating "$repository" repo
    echo
    (cd "$repository" && git pull)
  done
