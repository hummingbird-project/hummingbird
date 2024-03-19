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

/// File attributes required by ``FileMiddleware``
public struct FileAttributes: Sendable {
    /// Is file a folder
    public let isFolder: Bool
    /// Size of file
    public let size: Int
    /// Last time file was modified
    public let modificationDate: Date

    /// Initialize FileAttributes
    public init(isFolder: Bool, size: Int, modificationDate: Date) {
        self.isFolder = isFolder
        self.size = size
        self.modificationDate = modificationDate
    }
}

/// Protocol for file provider type used by ``FileMiddleware``
public protocol FileProvider: Sendable {
    /// Get full path name
    /// - Parameter path: path from URI
    /// - Returns: Full path
    func getFullPath(_ path: String) -> String

    /// Get file attributes
    /// - Parameter path: Full path to file
    /// - Returns: File attributes
    func getAttributes(path: String) async throws -> FileAttributes?

    /// Return a reponse body that will write the file body
    /// - Parameters:
    ///   - path: Full path to file
    ///   - context: Request context
    /// - Returns: Response body
    func loadFile(path: String, context: some BaseRequestContext) async throws -> ResponseBody

    /// Return a reponse body that will write a partial file body
    /// - Parameters:
    ///   - path: Full path to file
    ///   - range: Part of file to return
    ///   - context: Request context
    /// - Returns: Response body
    func loadFile(path: String, range: ClosedRange<Int>, context: some BaseRequestContext) async throws -> ResponseBody
}
