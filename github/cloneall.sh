#!/bin/bash

# Clone all repositories in a organization where the user is a member.

ORG=$1
TOKEN="token"

# This script uses (https://github.com/tegon/clone-org-repos)
# First download node.js then execute
# $ npm install clone-org-repos -g
#
# USAGE:
# First add the token in its variable, then execute
# ./cloneall <organization name> 

cloneorg $ORG --token $TOKEN