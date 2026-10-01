#!/bin/bash

#DOCC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc 
DOCC=docc
SG_FOLDER=$PWD/.build/symbol-graphs

swift build \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc $SG_FOLDER

cp .build/symbol-graphs/Hummingbird.symbols.json .build/hb-symbol-graphs
cp .build/symbol-graphs/Hummingbird@* .build/hb-symbol-graphs
cp .build/symbol-graphs/HummingbirdCore* .build/hbcore-symbol-graphs

$DOCC convert Sources/HummingbirdCore/Documentation.docc \
    --additional-symbol-graph-dir .build/hbcore-symbol-graphs \
    --output-path .docc-build/HummingbirdCore.doccarchive \
    --fallback-display-name HummingbirdCore \
    --fallback-bundle-identifier codes.hummingbird.hummingbirdcore \
    --fallback-bundle-version 1 \
    --enable-experimental-external-link-support

$DOCC convert Sources/Hummingbird/Documentation.docc \
    --additional-symbol-graph-dir .build/hb-symbol-graphs \
    --output-path .docc-build/Hummingbird.doccarchive \
    --dependency .docc-build/HummingbirdCore.doccarchive \
    --fallback-display-name Hummingbird \
    --fallback-bundle-identifier codes.hummingbird.hummingbird \
    --fallback-bundle-version 1 \
    --enable-experimental-external-link-support

rm -rf .docc-build/hb.doccarchive/*
$DOCC merge \
    .docc-build/HummingbirdCore.doccarchive \
    .docc-build/Hummingbird.doccarchive \
    --synthesized-landing-page-name "Hummingbird Documentation" \
    --synthesized-landing-page-kind "" \
    --synthesized-landing-page-topics-style list \
    --output-path .docc-build/hb.doccarchive 