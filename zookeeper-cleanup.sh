#!/bin/bash
startTime=$(date +%s)
function calculateTime() {
	endTime=$(date +%s)
	if [[ $# -eq 0 ]]
	then
		echo "Give at least one argument."
		exit 1
	fi

    case "$#" in
            1)
                echo "Total execution time: $((endTime-$1))s."
                exit 0
                ;;
            2)
                printf "$2" $((endTime-$1))
                exit 0
                ;;
            *)
                echo "Error. Exiting."
                exit 1
    esac
}

status=$(zkServer.sh status 2>/dev/null | tail -n 1 | awk -F " " '{print $2}')

case "$status" in
        "standalone")
            echo "Node is standalone."
            calculateTime $startTime
            exit 0
            ;;
        "follower")
            echo "Node is follower."
            calculateTime $startTime
            exit 0
            ;;
        "leader")
            echo "Node is leader."
            if [[ -z $SERVICE_NAME ]]
            then
                echo "Service name is null."
                calculateTime $startTime
                exit 1
            fi

            ZOO_REG_EX="^server\.\d{1,3}=(\d{1,3}\.){3}\d{1,3}:\d+:\d+(:(observer|participant))?;(\d{1,3}\.){3}\d{1,3}:\d+"
            directory=/usr/local/bin

            configurationStartTime=$(date +%s)
            echo "Getting and saving /zookeeper/config to $directory/configuration."
            zkCli.sh get /zookeeper/config | egrep $ZOO_REG_EX > $directory/configuration
            cat $directory/configuration
            message="Configuration execution time: %ss."
            calculateTime $configurationStartTime $message

            dictionaryStartTime=$(date +%s)
            declare -A dictionary
            for configuration in $(cat $directory/configuration)
            do
                ZOO_IP=$(echo $configuration | awk -F "[=:]" '{print $2}')
                ZOO_ID=$(echo $configuration | awk -F "[.=]" '{print $2}')
                echo "Saving to map ZOO_IP $ZOO_IP with ZOO_ID $ZOO_ID."
                dictionary["$ZOO_IP"]="$ZOO_ID"
            done
            message="Dictionary creation time: %ss."
            calculateTime $dictionaryStartTime $message
            echo "Dictionary contains ${#dictionary[@]} pairs."
            echo "Dictionary: ${dictionary[@]}."

            nodesStartTime=$(date +%s)
            echo "Digging and saving tasks.$SERVICE_NAME to $directory/nodes."
            dig tasks.$SERVICE_NAME +short > $directory/nodes
            cat $directory/nodes
            message="Nodes execution time: %ss."
            calculateTime $nodesStartTime $message

            removalStartTime=$(date +%s)
            removeFlag=0
            declare -a removeList
            echo "Looping through configuration dictionary."
            for ZOO_IP in ${!dictionary[@]}
            do
                check=$(grep -c $ZOO_IP $directory/nodes)
                echo "grep -c $ZOO_IP $directory/nodes equals $check."
                if [[ $check -eq 0 ]]
                then
                    removeFlag=1
                    ZOO_ID=${dictionary["$ZOO_IP"]}
                    echo "Node with ZOO_ID $ZOO_ID and ZOO_IP $ZOO_IP not found in $directory/nodes."
                    removeList+=("$ZOO_ID")
                fi
            done
            message="Removal execution time: %ss."
            calculateTime $removalStartTime $message

            additionStartTime=$(date +%s)
            addFlag=0
            declare -a addList
            echo "Looping through $directory/nodes."
            for ZOO_IP in $(cat $directory/nodes)
            do
                check=$(grep -c $ZOO_IP $directory/configuration)
                echo "grep -c $ZOO_IP $directory/configuration equals $check."
                if [[ $check -eq 0 ]]
                then
                    addFlag=1
                    ZOO_ID=$(($(echo $ZOO_IP | cut -d . -f 4)-1))
                    echo "Node with ZOO_ID $ZOO_ID and ZOO_IP $ZOO_IP not found in $directory/configuration."
                    addList+=("server.$ZOO_ID=$ZOO_IP:2888:3888;$ZOO_PORT")
                fi
            done
            message="Addition execution time: %ss."
            calculateTime $additionStartTime $message

            reconfigurationStartTime=$(date +%s)
            if [[ removeFlag -eq 1 && addFlag -eq 1 ]]
            then
                x=$(printf "%s," ${removeList[@]})
                y=$(printf "%s," ${addList[@]})
                echo "Reconfiguring nodes."
                zkCli.sh reconfig -remove ${x[@]:0:-1} -add ${y[@]:0:-1}
                unset removeList addList x y
            elif [[ removeFlag -eq 1 ]]
            then
                x=$(printf "%s," ${removeList[@]})
                echo "Removing nodes."
                zkCli.sh reconfig -remove ${x[@]:0:-1}
                unset removeList x
            elif [[ addFlag -eq 1 ]]
            then
                y=$(printf "%s," ${addList[@]})
                echo "Adding nodes."
                zkCli.sh reconfig -add ${y[@]:0:-1}
                unset addList y
            fi
            message="Reconfiguration execution time: %ss."
            calculateTime $reconfigurationStartTime $message

            calculateTime $startTime
            exit 0
            ;;
        *)
            echo "Node is not a member of a cluster."
            calculateTime $startTime
            exit 1
esac
calculateTime $startTime
exit 0
