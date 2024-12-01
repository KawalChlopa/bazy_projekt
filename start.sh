#!/bin/bash
while ! mysqladmin ping -h "localhost" --silent; do 
    sleep 1
done

python3 /app/bazy.py