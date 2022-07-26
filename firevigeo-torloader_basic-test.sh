#!/usr/bin/env bash

echo "Check connection!"

while true; do
   curl -s 'https://myip.privex.io/index.json' | jq .ip
   echo "Sleep for 5 seconds!"
   sleep 5
   echo "Recheck connection!"
done
