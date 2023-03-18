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

import Hummingbird
import HummingbirdXCT
import NIO
import NIOPosix

public protocol HBApplicationBenchmark {
    func setUp(_ application: HBApplication) throws
    func singleIteration(_ client: HBXCT) -> EventLoopFuture<HBXCTResponse>
}

public class HBApplicationBenchmarkWrapper<AB: HBApplicationBenchmark>: BenchmarkWrapper {
    let applicationBenchmarker: AB
    let iterations: Int

    var application: HBApplication!
    let configuration: HBApplication.Configuration

    public init(
        _ applicationBenchmarker: AB,
        iterations: Int = 1000,
        configuration: HBApplication.Configuration = .init(address: .hostname("127.0.0.1", port: 0), logLevel: .critical)
    ) {
        self.iterations = iterations
        self.applicationBenchmarker = applicationBenchmarker
        self.configuration = configuration
    }

    public func setUp() throws {
        // server setup
        self.application = HBApplication(testing: .embedded, configuration: self.configuration)
        try self.applicationBenchmarker.setUp(self.application)
        // start server
        try self.application.XCTStart()

        // warm up
        for _ in 0..<50 {
            _ = try self.applicationBenchmarker.singleIteration(self.application.xct).wait()
        }
    }

    public func run() throws {
        for _ in 0..<self.iterations {
            _ = try self.applicationBenchmarker.singleIteration(self.application.xct).wait()
        }
    }

    public func tearDown() {
        self.application.XCTStop()
    }
}
