#!/bin/bash

for i in `seq 100`; do
    curl http://localhost:8080 &
done
