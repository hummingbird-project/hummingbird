#!/bin/bash
# Script to test other hummingbird repos compile ok with version of
# Hummingbird in current folder
TEMP_DIR=$(mktemp -d)
echo "Using temp folder $TEMP_DIR"

set -eux

verify_repository()
{
    ADDRESS=$2
    BRANCH=$3
    REPODIR="$TEMP_DIR"/$(basename "$ADDRESS")
    CURRENTDIR=$(pwd)

    git clone $ADDRESS $REPODIR
    pushd $REPODIR
    git checkout $BRANCH
    swift package update
    swift package edit hummingbird-core --path "$CURRENTDIR"
    if [[ "$1" = "test" ]]; then
        swift test
    else
        swift build
    fi
    popd
}

# Test latest code against
verify_repository test https://github.com/hummingbird-project/hummingbird main
verify_repository test https://github.com/hummingbird-project/hummingbird-compression main
verify_repository build https://github.com/hummingbird-project/hummingbird-websocket main

rm -rf $TEMP_DIR
