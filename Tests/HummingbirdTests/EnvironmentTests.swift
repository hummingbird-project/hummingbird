//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
@testable import Hummingbird
import XCTest

final class EnvironmentTests: XCTestCase {
    func testInitFromEnvironment() {
        XCTAssertEqual(setenv("TEST_VAR", "testSetFromEnvironment", 1), 0)
        let env = Environment()
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromEnvironment")
    }

    func testInitFromDictionary() {
        let env = Environment(values: ["TEST_VAR": "testSetFromDictionary"])
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromDictionary")
    }

    func testInitFromCodable() {
        let json = #"{"TEST_VAR": "testSetFromCodable"}"#
        var env: Environment?
        XCTAssertNoThrow(env = try JSONDecoder().decode(Environment.self, from: Data(json.utf8)))
        XCTAssertEqual(env?.get("TEST_VAR"), "testSetFromCodable")
    }

    func testSet() {
        var env = Environment()
        env.set("TEST_VAR", value: "testSet")
        XCTAssertEqual(env.get("TEST_VAR"), "testSet")
    }

    func testLogLevel() {
        setenv("LOG_LEVEL", "trace", 1)
        let router = Router()
        let app = Application(responder: router.buildResponder())
        XCTAssertEqual(app.logger.logLevel, .trace)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(setenv("test_VAR", "testSetFromEnvironment", 1), 0)
        let env = Environment()
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromEnvironment")
        XCTAssertEqual(env.get("test_var"), "testSetFromEnvironment")
    }

    func testDotEnvLoading() async throws {
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
        XCTAssertEqual(result.get("test"), "this")
        XCTAssertEqual(result.get("credentials"), "sdkfjh")
    }

    func testDotEnvParsingError() throws {
        let dotenv = """
        TEST #thse
        """
        do {
            _ = try Environment.parseDotEnv(dotenv)
            XCTFail("Should fail")
        } catch let error as Environment.Error where error == .dotEnvParseError {}
    }

    func testDotEnvSpeechMarks() throws {
        let dotenv = """
        TEST="test this"
        CREDENTIALS=sdkfjh
        """
        let result = try Environment.parseDotEnv(dotenv)
        XCTAssertEqual(result["test"], "test this")
        XCTAssertEqual(result["credentials"], "sdkfjh")
    }

    func testDotEnvMultilineValue() throws {
        let dotenv = """
        TEST="test
        this"
        CREDENTIALS=sdkfjh
        """
        let result = try Environment.parseDotEnv(dotenv)
        XCTAssertEqual(result["test"], "test\nthis")
        XCTAssertEqual(result["credentials"], "sdkfjh")
    }

    func testDotEnvComments() throws {
        let dotenv = """
        # Comment 
        TEST=this # Comment at end of line
        CREDENTIALS=sdkfjh
        # Comment at end
        """
        let result = try Environment.parseDotEnv(dotenv)
        XCTAssertEqual(result["test"], "this")
        XCTAssertEqual(result["credentials"], "sdkfjh")
    }

    func testDotEnvCommentAndEmptyLine() throws {
        let dotenv = """
        FOO=BAR
        #BAZ=


        """
        let result = try Environment.parseDotEnv(dotenv)
        XCTAssertEqual(result["foo"], "BAR")
        XCTAssertEqual(result.count, 1)
    }

    func testEmptyLineAtEnd() throws {
        let dotenv = """
        FOO=BAR

        """
        let result = try Environment.parseDotEnv(dotenv)
        XCTAssertEqual(result["foo"], "BAR")
        XCTAssertEqual(result.count, 1)
    }

    func testDotEnvOverridingEnvironment() async throws {
        let dotenv = """
        TEST_VAR=testDotEnvOverridingEnvironment
        """
        let data = dotenv.data(using: .utf8)
        let envURL = URL(fileURLWithPath: ".override.env")
        try data?.write(to: envURL)
        defer {
            try? FileManager.default.removeItem(at: envURL)
        }
        XCTAssertEqual(setenv("TEST_VAR", "testSetFromEnvironment", 1), 0)
        XCTAssertEqual(setenv("TEST_VAR2", "testSetFromEnvironment2", 1), 0)
        let env = try await Environment().merging(with: .dotEnv(".override.env"))
        XCTAssertEqual(env.get("TEST_VAR"), "testDotEnvOverridingEnvironment")
        XCTAssertEqual(env.get("TEST_VAR2"), "testSetFromEnvironment2")
    }
}
