#!/usr/bin/env bash
# Generates HTTP traffic to nginx to produce access logs with varied status codes

NGINX_URL="http://nginx-proxy:80"

while true; do
    r=$((RANDOM % 100))

    if [ $r -lt 50 ]; then
        curl -s "$NGINX_URL/" > /dev/null 2>&1
    elif [ $r -lt 65 ]; then
        curl -s "$NGINX_URL/api/health" > /dev/null 2>&1
    elif [ $r -lt 75 ]; then
        curl -s "$NGINX_URL/admin/secret" > /dev/null 2>&1
    elif [ $r -lt 85 ]; then
        curl -s "$NGINX_URL/broken/endpoint" > /dev/null 2>&1
    elif [ $r -lt 90 ]; then
        curl -s "$NGINX_URL/nonexistent/$(shuf -i 1-999 -n 1)" > /dev/null 2>&1
    else
        curl -s --max-time 2 "$NGINX_URL/slow/" > /dev/null 2>&1
    fi

    sleep "0.$(shuf -i 1-9 -n 1)"
done
