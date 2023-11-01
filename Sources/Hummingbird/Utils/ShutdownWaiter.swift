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

import ServiceLifecycle

actor ShutdownWaiter {
    private var taskContinuation: CheckedContinuation<Void, Never>?

    init() {}

    func wait() async {
        await withGracefulShutdownHandler {
            await withCheckedContinuation { continuation in
                self.taskContinuation = continuation
            }
        } onGracefulShutdown: {
            Task {
                await self.stop()
            }
        }
    }

    private func stop() {
        self.taskContinuation?.resume()
        self.taskContinuation = nil
    }
}
