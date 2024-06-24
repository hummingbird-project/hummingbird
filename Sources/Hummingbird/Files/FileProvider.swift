//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIOPosix

/// Protocol for file provider type used by ``FileMiddleware``
public protocol FileProvider: Sendable {
    /// File attributes type
    associatedtype FileAttributes
    /// File identifier
    associatedtype FileIdentifier

    /// Get file identifier
    /// - Parameter path: path from URI
    /// - Returns: File Identifier
    func getFileIdentifier(_ path: String) throws -> FileIdentifier

    /// Append a file name component to a file identifier
    /// - Parameter
    ///   - filename: File name to append
    ///   - path: File Identifier
    /// - Returns: Resulting file identifier
    func appendFilenameComponent(_ filename: String, to path: FileIdentifier) -> FileIdentifier?

    /// Get file attributes
    /// - Parameter id: File identifier
    /// - Returns: File attributes
    func getAttributes(id: FileIdentifier) async throws -> FileAttributes?

    /// Return a reponse body that will write the file body
    /// - Parameters:
    ///   - id: File identifier
    ///   - context: Request context
    /// - Returns: Response body
    func loadFile(id: FileIdentifier, context: some RequestContext) async throws -> ResponseBody

    /// Return a reponse body that will write a partial file body
    /// - Parameters:
    ///   - id: File identifier
    ///   - range: Part of file to return
    ///   - context: Request context
    /// - Returns: Response body
    func loadFile(id: FileIdentifier, range: ClosedRange<Int>, context: some RequestContext) async throws -> ResponseBody
}
