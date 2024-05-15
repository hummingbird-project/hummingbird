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
import Logging
import NIOPosix

/// Local file system file provider used by FileMiddleware. All file accesses are relative to a root folder
public struct LocalFileSystem: FileProvider {
    /// File attributes required by ``FileMiddleware``
    public struct FileAttributes: Sendable, FileMiddlewareFileAttributes {
        /// Is file a folder
        public let isFolder: Bool
        /// Size of file
        public let size: Int
        /// Last time file was modified
        public let modificationDate: Date

        /// Initialize FileAttributes
        init(isFolder: Bool, size: Int, modificationDate: Date) {
            self.isFolder = isFolder
            self.size = size
            self.modificationDate = modificationDate
        }
    }

    let rootFolder: String
    let fileIO: FileIO

    /// Initialize LocalFileSystem FileProvider
    /// - Parameters:
    ///   - rootFolder: Root folder to serve files from
    ///   - threadPool: Thread pool used when loading files
    ///   - logger: Logger to output root folder information
    public init(rootFolder: String, threadPool: NIOThreadPool, logger: Logger) {
        if rootFolder.last != "/" {
            self.rootFolder = "\(rootFolder)/"
        } else {
            self.rootFolder = rootFolder
        }
        self.fileIO = .init(threadPool: threadPool)

        let workingFolder: String
        if rootFolder.first == "/" {
            workingFolder = ""
        } else {
            if let cwd = getcwd(nil, Int(PATH_MAX)) {
                workingFolder = String(cString: cwd) + "/"
                free(cwd)
            } else {
                workingFolder = "./"
            }
        }
        logger.info("Serving files from \(workingFolder)\(rootFolder)")
    }

    /// Get full path name with local file system root prefixed
    /// - Parameter path: path from URI
    /// - Returns: Full path
    public func getFullPath(_ path: String) -> String {
        if path.first == "/" {
            return "\(self.rootFolder)\(path.dropFirst())"
        } else {
            return "\(self.rootFolder)\(path)"
        }
    }

    /// Get file attributes
    /// - Parameter path: Full path to file
    /// - Returns: File attributes
    public func getAttributes(path: String) async throws -> FileAttributes? {
        do {
            let lstat = try await self.fileIO.fileIO.lstat(path: path)
            let isFolder = (lstat.st_mode & S_IFMT) == S_IFDIR
            #if os(Linux)
            let modificationDate = Double(lstat.st_mtim.tv_sec) + (Double(lstat.st_mtim.tv_nsec) / 1_000_000_000.0)
            #else
            let modificationDate = Double(lstat.st_mtimespec.tv_sec) + (Double(lstat.st_mtimespec.tv_nsec) / 1_000_000_000.0)
            #endif
            return .init(
                isFolder: isFolder,
                size: numericCast(lstat.st_size),
                modificationDate: Date(timeIntervalSince1970: modificationDate)
            )
        } catch {
            return nil
        }
    }

    /// Return a reponse body that will write the file body
    /// - Parameters:
    ///   - path: Full path to file
    ///   - context: Request context
    /// - Returns: Response body
    public func loadFile(path: String, context: some BaseRequestContext) async throws -> ResponseBody {
        try await self.fileIO.loadFile(path: path, context: context)
    }

    /// Return a reponse body that will write a partial file body
    /// - Parameters:
    ///   - path: Full path to file
    ///   - range: Part of file to return
    ///   - context: Request context
    /// - Returns: Response body
    public func loadFile(path: String, range: ClosedRange<Int>, context: some BaseRequestContext) async throws -> ResponseBody {
        try await self.fileIO.loadFile(path: path, range: range, context: context)
    }
}
