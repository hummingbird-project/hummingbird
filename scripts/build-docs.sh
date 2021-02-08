#!/usr/bin/env bash

set -eux

build_hummingbird_core() {
    VERSION=$1
    jazzy \
        --clean \
        --author "Adam Fowler" \
        --author_url https://github.com/adam-fowler \
        --github_url https://github.com/hummingbird-project/hummingbird-core \
        --module-version "$VERSION" \
        --module HummingbirdCore \
        --readme documentation/readme.md \
        --output docs/hummingbird-core
}

VERSION=""

while getopts 'v:' option
do
    case $option in
        v) VERSION=$OPTARG ;;
        *) usage ;;
    esac
done

build_hummingbird_core "$VERSION"
