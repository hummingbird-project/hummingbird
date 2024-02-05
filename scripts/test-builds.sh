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
    swift package edit hummingbird --path "$CURRENTDIR"
    if [[ "$1" = "test" ]]; then
        swift test
    else
        swift build
    fi
    popd
}

# Test latest code against
verify_repository test https://github.com/hummingbird-project/hummingbird-auth 2.x.x
#verify_repository test https://github.com/hummingbird-project/hummingbird-compression 2.x.x
verify_repository build https://github.com/hummingbird-project/hummingbird-fluent 2.x.x
verify_repository build https://github.com/hummingbird-project/hummingbird-lambda 2.x.x
verify_repository build https://github.com/hummingbird-project/hummingbird-redis 2.x.x
#verify_repository test https://github.com/hummingbird-project/hummingbird-websocket 2.x.x

rm -rf $TEMP_DIR
