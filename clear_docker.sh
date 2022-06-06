#!/bin/bash

sudo docker kill $(sudo docker ps -q)
sudo docker rm $(sudo docker ps -a -q)
sudo docker rmi $(sudo docker images -q)
sudo docker system prune --volumes <<< y
