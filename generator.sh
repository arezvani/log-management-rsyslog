#!/bin/bash

min=10000000
max=30000000
id=$RANDOM
long_int=$(($RANDOM%($max-$min+1)+$min))
percentage=55
population=$long_int
date_time=`date`
sun=25


example_message=$(cat <<EOF
{"status": "success","message": "Employee list","start": 0,"total_results": 1,"data": [{"empId": "$id","name": "Tim","designation": "Engineer"}]}
EOF
)

while true
do

#random_char=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
random_char=`openssl rand -hex 16`

if [ "$1" = "random_city" ]; then
if [ `date +%H` -lt 18 ] && [ `date +%H` -ge 6 ]; then sun=$(($sun*101/100)); else sun=$(($sun*99/100)); fi
message=$(cat <<EOF
{"$date_time" "$random_char" "iran": {"city": "Tehran","population": "$population","men": "$(($population*$percentage/100))","women": "$(($population*(100-$percentage)/100))","hOffset": "$(($population*2))","vOffset": "100","weather": "$sun"}
EOF
);

elif [ "$1" = "random_person" ]; then
message=$(curl -s https://randomuser.me/api/?results=1);
fi

if [ $# -eq 0 ]; then
    >&2 echo "No arguments provided"
    exit 1
else echo $message | nc -w 30 localhost $expose_port; #use -u for udp
fi

sleep 1

done
