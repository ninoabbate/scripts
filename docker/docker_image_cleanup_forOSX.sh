#!/bin/bash
#
# -----------------------------------------------------------------------------------------------------
# Description
# -----------------------------------------------------------------------------------------------------
#
# This script cleans all of the unused stuff from a docker installation in OSX, this is what it does:
# - Remove exited docker containers
# - Remove dangling images
# - Remove unused docker images
# - Remove unused docker volumes
#
# -----------------------------------------------------------------------------------------------------
# Requirements
# -----------------------------------------------------------------------------------------------------
#
# - docker
#
# -----------------------------------------------------------------------------------------------------

set -o errexit

echo "Removing exited docker containers..."
docker ps -a -f status=exited -f status=dead -q | xargs docker rm -v 

echo "Removing dangling images..."
docker images --no-trunc -q -f dangling=true | xargs docker rmi

echo "Removing unused docker images"
images=($(docker images | tail -n +2 | awk '{print $1":"$2}'))
containers=($(docker ps -a | tail -n +2 | awk '{print $2}'))

containers_reg=" ${containers[*]} "
remove=()

for item in ${images[@]}; do
  if [[ ! $containers_reg =~ " $item " ]]; then
    remove+=($item)
  fi
done

remove_images=" ${remove[*]} "

echo ${remove_images} | xargs docker rmi

# remove unused volumes:
echo "Removing unused docker volumes"

docker volume ls -qf dangling=true | xargs docker volume rm 

echo "Done"
