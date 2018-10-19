#!/bin/bash
if [[ $# -ne 1 ]]
then
    echo "Give exactly one executable argument."
    exit 1
fi

for (( i = 0; i < 12; i++ ))
do
    (sleep $(($i*5)) && $1 $((++i)) &>>"/var/log/$(date +%Y.%m.%d).log" 2>&1) &
done
exit 0
