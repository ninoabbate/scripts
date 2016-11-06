#!/bin/bash
#
# -----------------------------------------------------------------------------------------------------
# Description
# -----------------------------------------------------------------------------------------------------
#
# This script cleans all of the unused stuff from a docker installation, this is what it does:
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
# - jq
#
# -----------------------------------------------------------------------------------------------------

set -o errexit

echo "Removing exited docker containers..."
docker ps -a -f status=exited -f status=dead -q | xargs -r docker rm -v

echo "Removing dangling images..."
docker images --no-trunc -q -f dangling=true | xargs -r docker rmi

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

echo ${remove_images} | xargs -r docker rmi

# remove unused volumes:
echo "Removing unused docker volumes"
find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d | grep -vFf \
  <(docker ps -aq | xargs docker inspect | jq -r '.[] | .Mounts | .[] | .Name | select(.)') \
  | xargs -r rm -fr

echo "Done"
