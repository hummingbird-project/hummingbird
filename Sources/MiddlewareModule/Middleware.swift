//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-middleware open source project
//
// Copyright (c) 2023 Apple Inc. and the swift-middleware project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of swift-middleware project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public typealias Middleware<Input, Output, Context> = @Sendable (Input, Context, _ next: (Input, Context) async throws -> Output) async throws -> Output

public protocol MiddlewareProtocol<Input, Output, Context>: Sendable {
    associatedtype Input
    associatedtype Output
    associatedtype Context

    func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output
}
