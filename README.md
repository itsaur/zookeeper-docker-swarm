# zookeeper-docker-swarm

### Available Tags:
 - [3.5](https://github.com/itsaur/zookeeper-docker-swarm/blob/3.5/Dockerfile)

### What is Zookeeper with Docker Swarm?
This is an extension to the [official Zookeeper Docker image](https://store.docker.com/images/zookeeper). 
This image lets you configure Zookeeper in [replicated mode](http://zookeeper.apache.org/doc/current/zookeeperStarted.html#sc_RunningReplicatedZooKeeper) 
as a single docker service, instead of creating three (or more) different services for each one of your nodes as proposed by the official image.

You will need a docker overlay network and an environment variable named `SERVICE_NAME` that equals the docker service name, when creating the swarm service.
Using this variable, each container will be able to discover the rest ZooKeeper nodes in their network.

An example of the **docker network create** is:

```bash
docker network create \
    --driver overlay zookeeper-net
```

An example of the **docker service create** is:

```bash
docker service create \
    --env "SERVICE_NAME=zookeeper" \
    --name zookeeper \
    --network zookeeper-net \
    --publish 2181:2181 \
    --replicas=3 \
    itsaur/zookeeper-replicated
```
