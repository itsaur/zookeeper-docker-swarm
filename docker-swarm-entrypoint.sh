#!/bin/bash
function initialize() {
    echo "Initializing $1 ZooKeeper."
}

function healthy() {
    echo -n "Checking health. "
    HEALTHY=$(cat /usr/local/bin/HEALTHY)
}

function discoverNodes() {
    echo -n "Discovering nodes in cluster. "
    NODES=($(dig tasks.$SERVICE_NAME +short))
}

if [[ -n $SERVICE_NAME ]]
then initialize "replicated"
else initialize "standalone"
fi

echo "Container is initializing."
echo "Setting INITIALIZED=0."
echo 0 | tee /usr/local/bin/INITIALIZED 1>/dev/null

CONFIG="$ZOO_CONF_DIR/zoo.cfg"

{
    echo "clientPort=$ZOO_PORT"

    echo "dataDir=$ZOO_DATA_DIR"
    echo "dataLogDir=$ZOO_DATA_LOG_DIR"

    echo "tickTime=$ZOO_TICK_TIME"
    if [[ -n $SERVICE_NAME ]]
    then
        echo "initLimit=$ZOO_INIT_LIMIT"
        echo "syncLimit=$ZOO_SYNC_LIMIT"
    fi

    echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS"
    echo "reconfigEnabled=$ZOO_RECONFIG_ENABLED"
    echo "skipACL=$ZOO_SKIP_ACL"
} >> "$CONFIG"

healthy
while [[ $HEALTHY -eq 0 ]]
do
    echo "Sleeping for 1s."
    sleep 1
    healthy
done
echo "Healthy."

ZOO_MY_IP=$(hostname -i)
echo "My IP: $ZOO_MY_IP"

ZOO_MY_ID=$(($(echo $ZOO_MY_IP | cut -d . -f 4)-1))
echo "My ID: $ZOO_MY_ID"

echo "Initializing ZooKeeper with ID: $ZOO_MY_ID."
zkServer-initialize.sh --myid=$ZOO_MY_ID

if [[ -n $SERVICE_NAME ]]
then
    echo "dynamicConfigFile=$ZOO_DYNAMIC_CONFIG_FILE" >> "$CONFIG"

    su -c 'touch $ZOO_DYNAMIC_CONFIG_FILE' $ZOO_USER

    if [[ -z $REPLICAS ]]
    then
        echo "REPLICAS not supplied."
        exit 1
    fi

    [[ -z "$TIMEOUT" ]] && TIMEOUT=60

    startTime=$(date +%s)
    discoverNodes
    while [[ ${#NODES[@]} -lt $REPLICAS ]]
    do
        if [[ $(($(date +%s)-$startTime)) -ge $TIMEOUT ]]
        then
            echo "Could not find other nodes in ${TIMEOUT}s."
            exit 1
        fi
        echo "$(($(date +%s)-$startTime))s elapsed."
        sleep 1
        discoverNodes
    done
    echo "Found."

    for NODE_IP in ${NODES[@]}
    do
        INDEX=$(echo $NODE_IP | cut -d . -f 4)
        NODE_ID=$((--INDEX))
        ZOO_SERVERS+=("server.$NODE_ID=$NODE_IP:2888:3888;$ZOO_PORT")
    done

    DYNAMIC_CONFIG="$ZOO_DYNAMIC_CONFIG_FILE"

    {
        for ZOO_SERVER in ${ZOO_SERVERS[@]}
        do
            echo "$ZOO_SERVER"
        done
    } >> "$DYNAMIC_CONFIG"

    echo "Printing dynamic configuration..."
    cat "$DYNAMIC_CONFIG"

    ZOO_SERVERS=(${NODES[@]})

    echo "ZooKeeper servers in dynamic configuration: ${ZOO_SERVERS[@]}."
fi

echo "Container is initialized."
echo "Setting INITIALIZED=1."
echo 1 | tee /usr/local/bin/INITIALIZED 1>/dev/null
echo "Setting HEALTHY=0."
echo 0 | tee /usr/local/bin/HEALTHY 1>/dev/null

if [[ -n $SERVICE_NAME ]]
then
    crontab /usr/local/bin/crontab.txt
    crond -b -l 0
fi

echo "Executing docker-entrypoint for ZooKeeper with ID: $ZOO_MY_ID."
exec sh /docker-entrypoint.sh "$@"
