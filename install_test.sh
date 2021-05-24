#!/bin/bash

set -e
# set -o xtrace

cd "$(dirname "$0")"

echo "Waiting for local rocket.chat server to start"
./wait_http.sh "http://$TEST_IP:3000"
sleep 5

echo "Running tests on rocketchat"
./basic_test.sh "http://$TEST_IP:3000"

echo "Running tests on rocketchat through proxy"
./basic_test.sh https://$TEST_IP insecure

echo "Tests passed!"