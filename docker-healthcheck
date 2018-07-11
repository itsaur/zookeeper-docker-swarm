#!/bin/bash
set -eo pipefail

INITIALIZED=$(cat /usr/local/bin/INITIALIZED)
if [[ $INITIALIZED -eq 0 ]] && echo "Container is not yet initialized. Setting HEALTHY=1."
then echo 1 | tee /usr/local/bin/HEALTHY && exit 0
else echo "Container is initialized."
fi

host=$(hostname -i || echo 127.0.0.1)

if [[ $(netstat -lnpt | grep 8080 | wc -l) -gt 0 ]] && echo "AdminServer is listening on 8080."
then
	if [[ request=$(curl -fLSs "http://$host:8080/commands/ruok") && health=$(echo $request | jq -e ".error==null or error(.error)") ]]
	then
		if [[ -z $SERVICE_NAME && $(zkServer.sh status 2>/dev/null | tail -n 1 | egrep "Mode: standalone" | wc -l) -eq 1 ]] && echo "Node is standalone."
		then exit 0
		elif [[ -n $SERVICE_NAME && $(zkServer.sh status 2>/dev/null | tail -n 1 | egrep "Mode: (follower|leader)" | wc -l) -eq 1 ]] && echo "Node is a member of a cluster."
		then exit 0
		elif [[ -n $SERVICE_NAME ]] && echo "Node is not a member of a cluster. Searching for other nodes in network."
		then
			NODES=($(dig tasks.$SERVICE_NAME +short))
			[[ ${#NODES[@]} -gt 1 ]] && echo "${#NODES[@]} nodes were found."
			for NODE_IP in ${NODES[@]/$ZOO_MY_IP}
			do
				ZOO_REG_EX="^server.\d{1,3}=\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d+:\d+(:(observer|participant))?;\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d+"
				if [[ $(zkCli.sh -server $NODE_IP:2181 get /zookeeper/config | egrep $ZOO_REG_EX | wc -l) -gt 0 ]] && echo "A cluster was found. Attempting to add this node to cluster."
				then zkCli.sh -server $NODE_IP:2181 reconfig -add "server.$ZOO_MY_ID=$ZOO_MY_IP:2888:3888;$ZOO_PORT" && echo "Node was added successfully to cluster." && exit 0
				else echo "Node is not a member of a cluster."
				fi
			done
		fi
	fi
else echo "AdminServer is not listening on 8080."
fi

exit 1
