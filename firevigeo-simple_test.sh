#!/usr/bin/env bash

echo "Check connection!"

while true; do
   curl -s 'https://myip.privex.io/index.json' | jq .ip
   echo "Sleep for 1 seconds!"
   sleep 1
   echo "Recheck connection!"
done
