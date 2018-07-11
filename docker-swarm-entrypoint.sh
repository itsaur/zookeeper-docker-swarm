#!/bin/bash
function healthy() {
    HEALTHY=$(cat /usr/local/bin/HEALTHY)
}

function discoverNodes() {
    echo "Discovering other nodes in cluster..."
    NODES=$(dig tasks.$SERVICE_NAME +short)
}

if [[ -z $SERVICE_NAME ]]
then
    echo "Running standalone."
else
    echo "Running in Swarm mode for service: $SERVICE_NAME"

    healthy
    while [[ $HEALTHY -eq 0 ]]
    do
        sleep 1
        healthy
    done

    ZOO_MY_IP=$(hostname -i)
    echo "My IP: $ZOO_MY_IP"
    INDEX=$(echo $ZOO_MY_IP | cut -d . -f 4)
    ZOO_MY_ID=$((--INDEX))
    echo "My ID: $ZOO_MY_ID"

    discoverNodes
    while [[ -z $NODES ]]
    do
        sleep 1
        discoverNodes
    done

    for NODE_IP in ${NODES[@]}
    do
        INDEX=$(echo $NODE_IP | cut -d . -f 4)
        NODE_ID=$((--INDEX))
        ZOO_SERVERS+=("server.$NODE_ID=$NODE_IP:2888:3888;$ZOO_PORT")
    done

    CONFIG="$ZOO_CONF_DIR/zoo.cfg"

    echo "dataDir=$ZOO_DATA_DIR" >> "$CONFIG"
    echo "dataLogDir=$ZOO_DATA_LOG_DIR" >> "$CONFIG"

    echo "tickTime=$ZOO_TICK_TIME" >> "$CONFIG"
    echo "initLimit=$ZOO_INIT_LIMIT" >> "$CONFIG"
    echo "syncLimit=$ZOO_SYNC_LIMIT" >> "$CONFIG"

    echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS" >> "$CONFIG"
    echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED" >> "$CONFIG"
    echo "reconfigEnabled=$ZOO_RECONFIG_ENABLED" >> "$CONFIG"
    echo "skipACL=$ZOO_SKIP_ACL" >> "$CONFIG"
    echo "dynamicConfigFile=$ZOO_DYNAMIC_CONFIG_FILE" >> "$CONFIG"

    echo $ZOO_MY_ID >> $ZOO_DATA_DIR/myid

    su -c 'touch $ZOO_DYNAMIC_CONFIG_FILE' $ZOO_USER

    DYNAMIC_CONFIG="$ZOO_DYNAMIC_CONFIG_FILE"

    for ZOO_SERVER in ${ZOO_SERVERS[@]}
    do
        echo "$ZOO_SERVER" >> "$DYNAMIC_CONFIG"
    done

    ZOO_SERVERS=(${NODES[@]})

    echo "ZooKeeper servers in dynamic configuration: ${ZOO_SERVERS[@]}."

    ZOO_REG_EX="^server.\d{1,3}=\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d+:\d+(:(observer|participant))?;\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d+"

    if [[ -z $ZOO_SERVERS ]]
    then
        zkServer-initialize.sh --force --myid=$ZOO_MY_ID
    else
        for ZOO_SERVER in ${ZOO_SERVERS[@]}
        do
            if [[ $(zkCli.sh -server $ZOO_SERVER:2181 get /zookeeper/config | egrep $ZOO_REG_EX | wc -l) -gt 0 ]]
            then
                zkServer-initialize.sh --force --myid=$ZOO_MY_ID
                zkServer.sh start
                zkCli.sh -server $ZOO_SERVER:2181 reconfig -add "server.$ZOO_MY_ID=$ZOO_MY_IP:2888:3888;$ZOO_PORT"
                zkServer.sh stop
                break
            fi
        done
    fi

    echo 1 | tee /usr/local/bin/INITIALIZED
    rm /usr/local/bin/HEALTHY
fi

exec sh /docker-entrypoint.sh "$@"
