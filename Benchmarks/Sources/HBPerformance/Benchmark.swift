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

public protocol BenchmarkWrapper: AnyObject {
    func setUp() throws
    func tearDown()
    func run() throws
}

extension BenchmarkWrapper {
    public func tearDown() {}
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol AsyncBenchmarkWrapper: AnyObject, Sendable {
    func setUp() async throws
    func tearDown()
    func run() async throws
}

extension AsyncBenchmarkWrapper {
    public func tearDown() {}
}
