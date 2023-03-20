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
    func singleIteration(_ client: HBEmbeddedApplication) -> EventLoopFuture<HBEmbeddedApplication.Response>
}

public class HBApplicationBenchmarkWrapper<AB: HBApplicationBenchmark>: BenchmarkWrapper {
    let applicationBenchmarker: AB
    let iterations: Int

    var application: HBEmbeddedApplication
    let configuration: HBApplication.Configuration

    public init(
        _ applicationBenchmarker: AB,
        iterations: Int = 10000,
        configuration: HBApplication.Configuration = .init(address: .hostname("127.0.0.1", port: 0), logLevel: .critical)
    ) {
        self.iterations = iterations
        self.applicationBenchmarker = applicationBenchmarker
        self.configuration = configuration
        self.application = .init(configuration: self.configuration)
    }

    public func setUp() throws {
        // server setup
        try self.applicationBenchmarker.setUp(self.application.application)
        // start server
        try self.application.start()

        // warm up
        for _ in 0..<50 {
            _ = try self.applicationBenchmarker.singleIteration(self.application).wait()
        }
    }

    public func run() throws {
        for _ in 0..<self.iterations {
            _ = try self.applicationBenchmarker.singleIteration(self.application).wait()
        }
    }

    public func tearDown() {
        self.application.stop()
    }
}
