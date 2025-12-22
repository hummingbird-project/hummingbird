//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if ConfigurationSupport

import Configuration
import Hummingbird
import HummingbirdCore
import Testing

struct ConfigReaderTests {

    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testApplicationConfigReader() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "http.host": "0.0.0.0",
                    "http.port": 12300,
                    "http.serverName": "Test HB",
                ])
            ]
        )

        let appConfig = ApplicationConfiguration(reader: configReader.scoped(to: "http"))
        #expect(appConfig.address == .hostname("0.0.0.0", port: 12300))
        #expect(appConfig.serverName == "Test HB")
    }

    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testApplicationConfigReaderHostOnly() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "http.host": "0.0.0.0"
                ])
            ]
        )

        let appConfig = ApplicationConfiguration(reader: configReader.scoped(to: "http"))
        #expect(appConfig.address == .hostname("0.0.0.0", port: 8080))
    }

    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testApplicationConfigReaderPortOnly() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "http.port": 9000
                ])
            ]
        )

        let appConfig = ApplicationConfiguration(reader: configReader.scoped(to: "http"))
        #expect(appConfig.address == .hostname("127.0.0.1", port: 9000))
    }

    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testApplicationUnixDomainSocketConfigReader() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "http.unixDomainSocket": "/tmp/hb"
                ])
            ]
        )

        let appConfig = ApplicationConfiguration(reader: configReader.scoped(to: "http"))
        #expect(appConfig.address == .unixDomainSocket(path: "/tmp/hb"))
    }

    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testHTTP1ConfigReader() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "idleTimeout": 65.0
                ])
            ]
        )

        let http1Config = HTTP1Channel.Configuration(reader: configReader)
        #expect(http1Config.idleTimeout == .seconds(65))
    }
}

#endif
