#!/bin/bash
if [[ $# -ne 1 ]]
then
    echo "Job ID not supplied. Exiting."
    exit 1
fi

function log() {
	if [[ $# -ne 2 ]]
	then
		echo "Give exactly two arguments."
		return 1
	fi

    printf -v JOB "%02d" $1
    DATE=$(date -u '+%Y-%m-%d %H:%M:%S,%3N')
    MESSAGE=$2
    echo "[#$JOB][$DATE] $MESSAGE"
}

status=$(zkServer.sh status 2>/dev/null | tail -n 1 | awk -F " " '{print $2}')

case "$status" in
        "standalone")
            log $1 "Node is standalone."
            exit 0
            ;;
        "follower")
            log $1 "Node is follower."
            exit 0
            ;;
        "leader")
            log $1 "Node is leader."
            if [[ -z $SERVICE_NAME ]]
            then
                log $1 "Service name is null."
                exit 1
            fi

            ZOO_REG_EX="^server\.\d{1,3}=(\d{1,3}\.){3}\d{1,3}:\d+:\d+(:(observer|participant))?;(\d{1,3}\.){3}\d{1,3}:\d+"
            directory=/usr/local/bin

            log $1 "Getting configuration nodes of $SERVICE_NAME service."
            zkCli.sh get /zookeeper/config | egrep $ZOO_REG_EX > $directory/configuration

            declare -A dictionary
            for configuration in $(cat $directory/configuration)
            do
                ZOO_IP=$(echo $configuration | awk -F "[=:]" '{print $2}')
                ZOO_ID=$(echo $configuration | awk -F "[.=]" '{print $2}')
                log $1 "Saving to map ZOO_IP $ZOO_IP with ZOO_ID $ZOO_ID."
                dictionary["$ZOO_IP"]="$ZOO_ID"
            done
            z=$(printf "%s," ${dictionary[@]})
            log $1 "Configuration IDs: ${z[@]:0:-1}."

            log $1 "Getting current nodes of $SERVICE_NAME service."
            dig tasks.$SERVICE_NAME +short > $directory/nodes

            removeFlag=0
            declare -a removeList
            for ZOO_IP in ${!dictionary[@]}
            do
                check=$(grep -c $ZOO_IP $directory/nodes)
                if [[ $check -eq 0 ]]
                then
                    removeFlag=1
                    ZOO_ID=${dictionary["$ZOO_IP"]}
                    log $1 "Node with ZOO_ID $ZOO_ID and ZOO_IP $ZOO_IP not found in $directory/nodes."
                    removeList+=("$ZOO_ID")
                fi
            done

            addFlag=0
            declare -a addList
            for ZOO_IP in $(cat $directory/nodes)
            do
                check=$(grep -c $ZOO_IP $directory/configuration)
                if [[ $check -eq 0 ]]
                then
                    addFlag=1
                    ZOO_ID=$(($(echo $ZOO_IP | cut -d . -f 4)-1))
                    log $1 "Node with ZOO_ID $ZOO_ID and ZOO_IP $ZOO_IP not found in $directory/configuration."
                    addList+=("server.$ZOO_ID=$ZOO_IP:2888:3888;$ZOO_PORT")
                fi
            done

            if [[ removeFlag -eq 1 && addFlag -eq 1 ]]
            then
                x=$(printf "%s," ${removeList[@]})
                y=$(printf "%s," ${addList[@]})
                log $1 "Reconfiguring nodes."
                zkCli.sh reconfig -remove ${x[@]:0:-1} -add ${y[@]:0:-1}
                unset removeList addList x y
            elif [[ removeFlag -eq 1 ]]
            then
                x=$(printf "%s," ${removeList[@]})
                log $1 "Removing nodes."
                zkCli.sh reconfig -remove ${x[@]:0:-1}
                unset removeList x
            elif [[ addFlag -eq 1 ]]
            then
                y=$(printf "%s," ${addList[@]})
                log $1 "Adding nodes."
                zkCli.sh reconfig -add ${y[@]:0:-1}
                unset addList y
            fi

            exit 0
            ;;
        *)
            log $1 "Node is not a member of a cluster."
            exit 1
esac
exit 0
