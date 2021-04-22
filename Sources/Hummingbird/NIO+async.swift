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

#if compiler(>=5.5) && $AsyncAwait
import _Concurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension EventLoopFuture {
    /// Get the value/error from an `EventLoopFuture` in an `async` context.
    ///
    /// This function can be used to bridge an `EventLoopFuture` into the `async` world. Ie. if you're in an `async`
    /// function and want to get the result of this future.
    public func get() async throws -> Value {
        return try await withUnsafeThrowingContinuation { cont in
            self.whenComplete { result in
                switch result {
                case .success(let value):
                    cont.resume(returning: value)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension EventLoopPromise {
    /// Complete a future with the result (or error) of the `async` function `body`.
    ///
    /// This function can be used to bridge the `async` world into an `EventLoopPromise`.
    ///
    /// - parameters:
    ///   - body: The `async` function to run.
    public func completeWithAsync(_ body: @escaping () async throws -> Value) {
        detach {
            do {
                let value = try await body()
                self.succeed(value)
            } catch {
                self.fail(error)
            }
        }
    }
}

#endif // compiler(>=5.5) && $AsyncAwait
