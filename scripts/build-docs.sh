#!/usr/bin/env bash

set -eux

CWD=$(pwd)
TEMP_DIR=$(mktemp -d)

get_latest_version() {
    RELEASE_REVISION=$(git rev-list --tags --max-count=1)
    echo $(git describe --tags "$RELEASE_REVISION")
}

build_docs() {
    MODULE_NAME=$1
    GITHUB_FOLDER=$2
    DOCS_FOLDER=$3
    VERSION=$(get_latest_version)
    jazzy \
        --clean \
        --author "Adam Fowler" \
        --author_url https://github.com/adam-fowler \
        --github_url https://github.com/hummingbird-project/"$GITHUB_FOLDER" \
        --module-version "$VERSION" \
        --module "$MODULE_NAME" \
        --readme "$CWD"/documentation/readme.md \
        --output "$CWD"/docs/"$DOCS_FOLDER"
}

build_docs_from_other_repo() {
    GITHUB_FOLDER=$2

    pushd "$TEMP_DIR"
    git clone https://github.com/hummingbird-project/"$GITHUB_FOLDER"
    cd "$GITHUB_FOLDER"
    build_docs $1 $2 $3

    popd
}

build_docs Hummingbird hummingbird hummingbird
build_docs HummingbirdFoundation hummingbird hummingbird-foundation
build_docs HummingbirdXCT hummingbird hummingbird-xct

build_docs_from_other_repo HummingbirdCore hummingbird-core hummingbird-core
build_docs_from_other_repo HummingbirdAuth hummingbird-auth hummingbird-auth


rm -rf "$TEMP_DIR"
