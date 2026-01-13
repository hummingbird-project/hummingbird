//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Testing

@testable import Hummingbird

@Suite("EnvironmentTests", .serialized)
struct EnvironmentTests {
    @Test func testInitFromEnvironment() {
        #expect(setenv("testInitFromEnvironment", "testSetFromEnvironment", 1) == 0)
        let env = Environment()
        #expect(env.get("testInitFromEnvironment") == "testSetFromEnvironment")
    }

    @Test func testInitFromDictionary() {
        let env = Environment(values: ["TEST_VAR": "testSetFromDictionary"])
        #expect(env.get("TEST_VAR") == "testSetFromDictionary")
    }

    @Test func testInitFromCodable() {
        let json = #"{"testInitFromCodable": "testSetFromCodable"}"#
        var env: Environment?
        #expect(throws: Never.self) { env = try JSONDecoder().decode(Environment.self, from: Data(json.utf8)) }
        #expect(env?.get("testInitFromCodable") == "testSetFromCodable")
    }

    @Test func testRequire() throws {
        var env = Environment()
        env.set("TEST_REQUIRE", value: "testing")
        let value = try env.require("TEST_REQUIRE")
        #expect(value == "testing")
        #expect(throws: Environment.Error.variableDoesNotExist) { try env.require("TEST_REQUIRE2") }
    }

    @Test func testRequireAs() throws {
        var env = Environment()
        env.set("TEST_REQUIRE_AS", value: "testing")
        let value = try env.require("TEST_REQUIRE_AS", as: String.self)
        #expect(value == "testing")
        #expect(throws: Environment.Error.variableDoesNotExist) { try env.require("TEST_REQUIRE_AS_2", as: Int.self) }
        #expect(throws: Environment.Error.variableDoesNotConvert) { try env.require("TEST_REQUIRE_AS", as: Int.self) }
    }

    @Test func testSet() {
        var env = Environment()
        env.set("TEST_VAR", value: "testSet")
        #expect(env.get("TEST_VAR") == "testSet")
    }

    @Test func testSetForAllEnvironments() {
        var env = Environment()
        env.set("TEST_VAR_E1", value: "testSet")
        let env2 = Environment()
        #expect(env2.get("TEST_VAR_E1") == "testSet")
    }

    @Test func testLogLevel() {
        var env = Environment()
        env.set("LOG_LEVEL", value: "trace")
        let router = Router()
        let app = Application(responder: router.buildResponder())
        #expect(app.logger.logLevel == .trace)
    }

    @Test func testCaseInsensitive() {
        #expect(setenv("testCaseInsensitive", "testSetFromEnvironment", 1) == 0)
        let env = Environment()
        #expect(env.get("TESTCaseInsensitive") == "testSetFromEnvironment")
        #expect(env.get("testcaseinsensitive") == "testSetFromEnvironment")
    }

    @Test func testDotEnvLoading() async throws {
        let dotenv = """
            TEST=this
            CREDENTIALS=sdkfjh
            """
        let data = dotenv.data(using: .utf8)
        let envURL = URL(fileURLWithPath: ".env")
        try data?.write(to: envURL)
        defer {
            try? FileManager.default.removeItem(at: envURL)
        }

        let result = try await Environment.dotEnv()
        #expect(result.get("test") == "this")
        #expect(result.get("credentials") == "sdkfjh")
    }

    @Test func testDotEnvParsingError() throws {
        let dotenv = """
            TEST #thse
            """
        #expect(throws: Environment.Error.dotEnvParseError) {
            try Environment.parseDotEnv(dotenv)
        }
    }

    @Test func testDotEnvSpeechMarks() throws {
        let dotenv = """
            TEST="test this"
            CREDENTIALS=sdkfjh
            """
        let result = try Environment.parseDotEnv(dotenv)
        #expect(result["test"] == "test this")
        #expect(result["credentials"] == "sdkfjh")
    }

    @Test func testDotEnvMultilineValue() throws {
        let dotenv = """
            TEST="test
            this"
            CREDENTIALS=sdkfjh
            """
        let result = try Environment.parseDotEnv(dotenv)
        #expect(result["test"] == "test\nthis")
        #expect(result["credentials"] == "sdkfjh")
    }

    @Test func testDotEnvComments() throws {
        let dotenv = """
            # Comment 
            TEST=this # Comment at end of line
            CREDENTIALS=sdkfjh
            # Comment at end
            """
        let result = try Environment.parseDotEnv(dotenv)
        #expect(result["test"] == "this")
        #expect(result["credentials"] == "sdkfjh")
    }

    @Test func testDotEnvCommentAndEmptyLine() throws {
        let dotenv = """
            FOO=BAR
            #BAZ=


            """
        let result = try Environment.parseDotEnv(dotenv)
        #expect(result["foo"] == "BAR")
        #expect(result.count == 1)
    }

    @Test func testEmptyLineAtEnd() throws {
        let dotenv = """
            FOO=BAR

            """
        let result = try Environment.parseDotEnv(dotenv)
        #expect(result["foo"] == "BAR")
        #expect(result.count == 1)
    }

    @Test func testDotEnvOverridingEnvironment() async throws {
        let dotenv = """
            testDotEnvOverridingEnvironment=testDotEnvOverridingEnvironment
            """
        let data = dotenv.data(using: .utf8)
        let envURL = URL(fileURLWithPath: ".override.env")
        try data?.write(to: envURL)
        defer {
            try? FileManager.default.removeItem(at: envURL)
        }
        #expect(setenv("testDotEnvOverridingEnvironment", "testSetFromEnvironment", 1) == 0)
        #expect(setenv("testDotEnvOverridingEnvironment2", "testSetFromEnvironment2", 1) == 0)
        let env = try await Environment().merging(with: .dotEnv(".override.env"))
        #expect(env.get("testDotEnvOverridingEnvironment") == "testDotEnvOverridingEnvironment")
        #expect(env.get("testDotEnvOverridingEnvironment2") == "testSetFromEnvironment2")
    }
}
