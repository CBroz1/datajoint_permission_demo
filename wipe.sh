!#/bin/bash

for i in {60..0}; do
  docker volume prune -f
  echo -ne "Wiped volumes $i                                        \r"
  sleep 5m
done

