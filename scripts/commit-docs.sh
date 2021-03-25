#!/bin/bash

set -eux

FOLDER=current
SUBFOLDER=${1:-}

# stash everything that isn't in docs, store result in STASH_RESULT
STASH_RESULT=$(git stash push -- ":(exclude)docs")
# get branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REVISION_HASH=$(git rev-parse HEAD)

git checkout gh-pages
if [[ -z "$SUBFOLDER" ]]; then
    # copy contents of docs to docs/current replacing the ones that are already there
    rm -rf "$FOLDER"
    mv docs/ "$FOLDER"/
    # commit
    git add --all "$FOLDER"
else
    # copy contents of subfolder of docs to docs/current replacing the ones that are already there
    rm -rf "$FOLDER"/"$SUBFOLDER"
    mv docs/"$SUBFOLDER"/ "$FOLDER"/"$SUBFOLDER"
    # commit
    git add --all "$FOLDER"/"$SUBFOLDER"
fi

git status
git commit -m "Documentation for https://github.com/hummingbird-project/hummingbird/tree/$REVISION_HASH"
git push
# return to branch
git checkout $CURRENT_BRANCH

if [ "$STASH_RESULT" != "No local changes to save" ]; then
    git stash pop
fi

