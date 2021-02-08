#!/usr/bin/env bash

set -eux

build_hummingbird() {
    VERSION=$1
    jazzy \
        --clean \
        --author "Adam Fowler" \
        --author_url https://github.com/adam-fowler \
        --github_url https://github.com/hummingbird-project/hummingbird \
        --module-version "$VERSION" \
        --module Hummingbird \
        --readme documentation/readme.md \
        --output docs/hummingbird
}

build_hummingbird_foundation() {
    VERSION=$1
    jazzy \
        --clean \
        --author "Adam Fowler" \
        --author_url https://github.com/adam-fowler \
        --github_url https://github.com/hummingbird-project/hummingbird \
        --module-version "$VERSION" \
        --module HummingbirdFoundation \
        --readme documentation/readme.md \
        --output docs/hummingbird-foundation
}

build_hummingbird_xct() {
    VERSION=$1
    jazzy \
        --clean \
        --author "Adam Fowler" \
        --author_url https://github.com/adam-fowler \
        --github_url https://github.com/hummingbird-project/hummingbird \
        --module-version "$VERSION" \
        --module HummingbirdXCT \
        --readme documentation/readme.md \
        --output docs/hummingbird-xct
}

VERSION=""

while getopts 'v:' option
do
    case $option in
        v) VERSION=$OPTARG ;;
        *) usage ;;
    esac
done

build_hummingbird "$VERSION"
build_hummingbird_foundation "$VERSION"
build_hummingbird_xct "$VERSION"
