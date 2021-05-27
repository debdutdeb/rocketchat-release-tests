#!/bin/bash

set -e
# set -o xtrace

SNAPFILE="$(realpath "$1")"

cd "$(dirname "$0")"

echo "Installing rocketchat"
sudo snap install --dangerous "$SNAPFILE"

./wait_http.sh "http://127.0.0.1:3000"

echo "Running tests on rocketchat"
./basic_test.sh "http://127.0.0.1:3000"

echo "Setting up caddy"
sudo snap set rocketchat-server caddy-url=https://localhost
sudo snap set rocketchat-server caddy=enable
sudo rocketchat-server.initcaddy

sudo snap restart rocketchat-server

./wait_http.sh "http://127.0.0.1:3000"

echo "Running basic test through caddy"
#TODO: test https eventually
. ./basic_test.sh http://127.0.0.1:3000

echo "Backing up database"
sudo systemctl stop snap.rocketchat-server.rocketchat-server
backup_path="$(sudo rocketchat-server.backupdb | egrep -o '/var/snap/rocketchat-server/(.+).tar.gz')"
backup_filename="$(basename "$backup_path")"
sudo mv "$backup_path" .

echo "Reinstalling rocketchat"
sudo snap remove rocketchat-server
sudo snap install --dangerous "$SNAPFILE"
sleep 10

echo "Restoring database"
sudo systemctl stop snap.rocketchat-server.rocketchat-server
sudo mv "$backup_filename" /var/snap/rocketchat-server/common/
yes 1 | sudo rocketchat-server.restoredb "/var/snap/rocketchat-server/common/$backup_filename"
sudo systemctl start snap.rocketchat-server.rocketchat-server

./wait_http.sh "http://127.0.0.1:3000"

echo "Checking if restore was successful"
test_endpoint "$base_url/api/v1/channels.messages?roomId=GENERAL" -H "$userId" -H "$authToken"
if [[ "$response" != *"This is a test message from $TEST_USER"* ]]; then
  echo "Couldn't find sent message. Somethings wrong!"
  exit 2
fi

echo "Checking external mongo access"
response="$(rocketchat-server.mongo parties --eval 'db.rocketchat_message.find()')"
if [[ "$response" != *"This is a test message from $TEST_USER"* ]]; then
  echo "Couldn't find sent message. Somethings wrong!"
  exit 2
fi

echo "Tests passed!"