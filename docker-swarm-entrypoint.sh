#!/bin/bash

if [ -z ${SERVICE_NAME} ];then
    echo "Running as a single container"
else
    echo "Running in Swarm mode"
    echo "Discovering other nodes in cluster..."

    SWARM_SERVICE_IPs=""
    while [ -z "$SWARM_SERVICE_IPs" ]; do
        sleep 5
        SWARM_SERVICE_IPs=$(dig tasks.${SERVICE_NAME} +short)
    done

    SORTED_IPS=$(echo ${SWARM_SERVICE_IPs} | tr " " "\n"|sort|tr "\n" " ")

    echo "Nodes of service ${SERVICE_NAME}:"
    echo "$SORTED_IPS"

    HOSTNAME=$(hostname)
    MY_IP=$(dig ${HOSTNAME} +short)
    echo "My IP: ${MY_IP}"

    declare -i server_number=1;
    SERVERS=""
    for NODE_IP in $SORTED_IPS
    do
        SERVER="server.${server_number}=${NODE_IP}:2888:3888"
        SERVERS="${SERVERS}${SERVER} "

        if [ "${NODE_IP}" == "${MY_IP}" ];then
            export ZOO_MY_ID=${server_number}
            echo "MY_ID: ${server_number}"
            echo "Setting ZOO_MY_ID: ${ZOO_MY_ID}"
        fi

        server_number=$((server_number+1));
    done

    export ZOO_SERVERS="${SERVERS% }"
    echo "Setting Servers: ${SERVERS% }"
    echo "ZOO_SERVERS: ${ZOO_SERVERS}"
fi

exec sh /docker-entrypoint.sh "$@"