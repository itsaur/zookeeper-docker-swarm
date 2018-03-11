# zookeeper-docker-swarm
This is an extension to the [official Zookeeper Docker image](https://store.docker.com/images/zookeeper). 
This image let's you configure Zookeeper in cluster mode as a single docker service, instead of
creating three (or more) different services for each one of your nodes as proposed by the official image.

The only thing needed is to provide the environment variable `SERVICE_NAME` 
having as value the name of your docker service. Using this variable, each container will 
be able to discover the rest Zookeeper nodes.

An example of the Docker Service create command is:

```bash
docker service create \
    --name zookeeper
    -p 2181:2181 \
    -e "SERVICE_NAME=zookeeper" \
    itsaur/zookeeper
```