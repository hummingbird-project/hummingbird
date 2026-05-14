//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// ``UnsafeTransfer`` can be used to make non-`Sendable` values `Sendable`.
/// As the name implies, the usage of this is unsafe because it disables the sendable checking of the compiler.
/// It can be used similar to `@unchecked Sendable` but for values instead of types.
@usableFromInline
package struct UnsafeTransfer<Wrapped> {
    @usableFromInline
    package var wrappedValue: Wrapped

    @inlinable
    package init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}

extension UnsafeTransfer: @unchecked Sendable {}

extension UnsafeTransfer: Equatable where Wrapped: Equatable {}
extension UnsafeTransfer: Hashable where Wrapped: Hashable {}
