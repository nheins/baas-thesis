#!/usr/bin/env sh

set -e
URL="localhost:4848"

HEADERS=$(cat <<EOF
Content-Type: application/json
Origin: http://localhost:9090
Type: system
EOF
)

curl -X POST "${URL}/user" -H "$HEADERS" -d @- <<EOF
{"username": "$1", "email": "${1}@localhost", "role": "user", "name": "$1" }
EOF
