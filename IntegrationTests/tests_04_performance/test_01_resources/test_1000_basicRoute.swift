//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import HummingbirdCoreXCT
import NIO

func run(identifier: String) {
    do {
        let setup = try Setup { app in
            app.router.get { _ in
                return "Hello, world!"
            }
        }

        measure(identifier: identifier) {
            let iterations = 1000
            for _ in 0..<iterations {
                let future = setup.client.get("/")
                _ = try? future.wait()
            }
            return iterations
        }
    } catch {
        print(error)
    }
}

