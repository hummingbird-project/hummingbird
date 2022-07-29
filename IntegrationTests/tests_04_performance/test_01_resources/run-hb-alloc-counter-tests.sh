#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2019 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

tmp_dir="/tmp"

while getopts "t:" opt; do
    case "$opt" in
        t)
            tmp_dir="$OPTARG"
            ;;
        *)
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

tests_to_run=("$here"/test_*.swift)

if [[ $# -gt 0 ]]; then
    tests_to_run=("$@")
fi

"$here/../../allocation-counter-tests-framework/run-allocation-counter.sh" \
    -p "$here/../../.." \
    -m ".product(name: \"Hummingbird\", package: \"hummingbird\")" \
    -m ".product(name: \"HummingbirdCoreXCT\", package: \"hummingbird-core\")" \
    -s "$here/shared.swift" \
    -t "$tmp_dir" \
    -d "$here/extra-dependencies.txt" \
    "${tests_to_run[@]}"
