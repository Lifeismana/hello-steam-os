#!/bin/bash

cd "${0%/*}"
. ../common.sh

echo "Processing SteamOS..."

ProcessDepot ".dll"
ProcessDepot ".exe"
ProcessDepot ".pyz"
FixUCS2

CreateCommit "$(cat bin/version.txt | grep -o '[0-9\.]*')" "$1"