#!/usr/bin/env bash

echo "Building image ..."
docker build -t test_priv .

CONTAINER_ID=$(docker run -t -d -v /boot/config:/config --privileged --net=host test_priv)
echo ${CONTAINER_ID}

echo "Connecting to container ..."
docker exec -it "${CONTAINER_ID}" /bin/bash

echo "Stopping and removing container ... "
docker stop "${CONTAINER_ID}"
docker rm "${CONTAINER_ID}"

