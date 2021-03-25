#!/usr/bin/env bash

set -eux

PROJECT=${1:-}
CWD=$(pwd)
TEMP_DIR=$(mktemp -d)

get_latest_version() {
    RELEASE_REVISION=$(git rev-list --tags --max-count=1)
    echo $(git describe --tags "$RELEASE_REVISION")
}

build_docs() {
    GITHUB_FOLDER=$1
    DOCS_FOLDER=$2
    shift 2
    MODULES=$*

    if [[ -n "$PROJECT" ]]; then
        if [[ "$DOCS_FOLDER" != "$PROJECT" ]]; then
            return
        fi
    fi
    SOURCEKITTEN_FOLDER="$TEMP_DIR/sourcekitten/$DOCS_FOLDER"

    mkdir -p $SOURCEKITTEN_FOLDER

    SOURCEKITTEN_FILES=""
    for MODULE in $MODULES;
    do
        echo "$MODULE"
        sourcekitten doc --spm --module-name "$MODULE" > $SOURCEKITTEN_FOLDER/"$MODULE".json
        if [ -z "$SOURCEKITTEN_FILES" ]; then
            SOURCEKITTEN_FILES=$SOURCEKITTEN_FOLDER/"$MODULE".json
        else
            SOURCEKITTEN_FILES="$SOURCEKITTEN_FILES,$SOURCEKITTEN_FOLDER/"$MODULE".json"
        fi
    done

    VERSION=$(get_latest_version)
    jazzy \
        --clean \
        --author "Adam Fowler" \
        --author_url https://github.com/adam-fowler \
        --github_url https://github.com/hummingbird-project/"$GITHUB_FOLDER" \
        --module-version "$VERSION" \
        --sourcekitten-sourcefile "$SOURCEKITTEN_FILES" \
        --readme "$CWD"/documentation/readme.md \
        --documentation "documentation/[^r]*.md" \
        --output "$CWD"/docs/"$DOCS_FOLDER"
}

build_docs_from_other_repo() {
    GITHUB_FOLDER=$1

    pushd "$TEMP_DIR"
    git clone https://github.com/hummingbird-project/"$GITHUB_FOLDER"
    cd "$GITHUB_FOLDER"
    build_docs $*

    popd
}

build_docs hummingbird hummingbird Hummingbird
build_docs hummingbird hummingbird-foundation HummingbirdFoundation
build_docs hummingbird hummingbird-xct HummingbirdXCT

build_docs_from_other_repo hummingbird-core hummingbird-core HummingbirdCore
build_docs_from_other_repo hummingbird-auth hummingbird-auth HummingbirdAuth
build_docs_from_other_repo hummingbird-mustache hummingbird-mustache HummingbirdMustache
build_docs_from_other_repo hummingbird-websocket hummingbird-websocket HummingbirdWebSocket HummingbirdWSCore


rm -rf "$TEMP_DIR"
