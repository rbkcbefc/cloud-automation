#!/bin/bash

## Configure cluster name using the template variable ${ecs_cluster_name}
echo "user data script starting!"
sudo mkdir -p /etc/ecs
sudo echo ECS_CLUSTER='${ecs_cluster_name}' >> /etc/ecs/ecs.config
sudo echo ECS_LOGLEVEL=debug >> /etc/ecs/ecs.config
#sudo systemctl start ecs
sudo systemctl daemon-reload
sudo systemctl restart docker.socket
sudo systemctl restart docker
sudo systemctl enable --now --no-block ecs
echo "user data script complete!"