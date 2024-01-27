#!/bin/bash

set -eu

HOME=$(dirname "$0")
FULL_HOME="$(pwd)"/"$HOME"
SERVER=hummingbird.codes

function generateCA() {
    SUBJECT=$1
    openssl req \
        -nodes \
        -x509 \
        -sha256 \
        -newkey rsa:2048 \
        -subj "$SUBJECT" \
        -days 365 \
        -keyout ca.key \
        -out ca.pem
    openssl x509 -in ca.pem -out ca.der -outform DER
}

function generateServerCertificate() {
    SUBJECT=$1
    NAME=$2
    openssl req \
        -new \
        -nodes \
        -sha256 \
        -subj "$SUBJECT" \
        -extensions v3_req \
        -reqexts SAN \
        -config <(cat "$FULL_HOME"/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$SERVER\n")) \
        -keyout "$NAME".key \
        -out "$NAME".csr
        
    openssl x509 \
        -req \
        -sha256 \
        -in "$NAME".csr \
        -CA ca.pem \
        -CAkey ca.key \
        -CAcreateserial \
        -extfile <(cat "$FULL_HOME"/openssl.cnf <(printf "subjectAltName=DNS:$SERVER\n")) \
        -extensions v3_req \
        -out "$NAME".pem \
        -days 365
}

function generateClientCertificate() {
    SUBJECT=$1
    NAME=$2
    PASSWORD=MyPassword
    openssl req \
        -new \
        -nodes \
        -sha256 \
        -subj "$SUBJECT" \
        -keyout "$NAME".key \
        -out "$NAME".csr
        
    openssl x509 \
        -req \
        -sha256 \
        -in "$NAME".csr \
        -CA ca.pem \
        -CAkey ca.key \
        -CAcreateserial \
        -out "$NAME".pem \
        -days 365

    TSTESTP12="$FULL_HOME/../Tests/HummingbirdCoreTests/Certificates/server.p12"
    openssl pkcs12 -export -passout pass:"$PASSWORD" -out "$TSTESTP12" -in "$NAME".pem -inkey "$NAME".key
}

function createCertSwiftFile() {
    FILENAME=$1
    cat > "$FILENAME" <<"EOF" 
//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird open source project
//
// Copyright (c) YEARS the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
EOF
    printf "
import NIOSSL

let testServerName = \"$SERVER\"

let caCertificateData =
\"\"\"\n$(cat ca.pem)
\"\"\"

let serverCertificateData =
\"\"\"\n$(cat server.pem)
\"\"\"

let serverPrivateKeyData =
\"\"\"\n$(cat server.key)
\"\"\"

let clientCertificateData =
\"\"\"\n$(cat client.pem)
\"\"\"

let clientPrivateKeyData =
\"\"\"\n$(cat client.key)
\"\"\"

func getServerTLSConfiguration() throws -> TLSConfiguration {
    let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
    let certificate = try NIOSSLCertificate(bytes: [UInt8](serverCertificateData.utf8), format: .pem)
    let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](serverPrivateKeyData.utf8), format: .pem)
    var tlsConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
    tlsConfig.trustRoots = .certificates([caCertificate])
    return tlsConfig
}

func getClientTLSConfiguration() throws -> TLSConfiguration {
    let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
    let certificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData.utf8), format: .pem)
    let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](clientPrivateKeyData.utf8), format: .pem)
    var tlsConfig = TLSConfiguration.makeClientConfiguration()
    tlsConfig.trustRoots = .certificates([caCertificate])
    tlsConfig.certificateChain = [.certificate(certificate)]
    tlsConfig.privateKey = .privateKey(privateKey)
    return tlsConfig
}
" >> "$FILENAME"
}

TMPDIR=$(mktemp -d /tmp/.workingXXXXXX)
cd "$TMPDIR"

generateCA "/C=UK/ST=Edinburgh/L=Edinburgh/O=MQTTNIO/OU=CA/CN=${SERVER}"
generateServerCertificate "/C=UK/ST=Edinburgh/L=Edinburgh/O=MQTTNIO/OU=Server/CN=${SERVER}" server
generateClientCertificate "/C=UK/ST=Edinburgh/L=Edinburgh/O=MQTTNIO/OU=Client/CN=${SERVER}" client

createCertSwiftFile $FULL_HOME/../Tests/HummingbirdTLSTests/Certificates.swift
createCertSwiftFile $FULL_HOME/../Tests/HummingbirdCoreTests/Certificates.swift

rm -rf "$TMPDIR"
