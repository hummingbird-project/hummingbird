//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Lifecycle

/// Define where we get the ServiceLifecycle from.
public enum ServiceLifecycleProvider {
    /// Use a `ServiceLifecycle` provided by the user
    /// and run `HBApplication` tasks in a `ComponentLifecycle`.
    case shared(ServiceLifecycle)

    /// Create a new `ServiceLifecycle`.
    case createNew
}
