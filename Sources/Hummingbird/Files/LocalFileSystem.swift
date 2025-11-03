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

#if !os(Windows)
public import Logging
public import NIOPosix

#if canImport(FoundationEssentials)
public import FoundationEssentials
import CNIOLinux
#else
public import Foundation
#endif

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

    /// File Identifier (Fully qualified path)
    public typealias FileIdentifier = String

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
    public func getFileIdentifier(_ path: String) -> FileIdentifier? {
        if path.first == "/" {
            return "\(self.rootFolder)\(path.dropFirst())"
        } else {
            return "\(self.rootFolder)\(path)"
        }
    }

    /// Get file attributes
    /// - Parameter path: FileIdentifier
    /// - Returns: File attributes
    public func getAttributes(id path: FileIdentifier) async throws -> FileAttributes? {
        do {
            let stat = try await self.fileIO.fileIO.stat(path: path)
            let isFolder = (stat.st_mode & S_IFMT) == S_IFDIR
            #if os(Linux) || os(Android)
            let modificationDate = Double(stat.st_mtim.tv_sec) + (Double(stat.st_mtim.tv_nsec) / 1_000_000_000.0)
            #else
            let modificationDate = Double(stat.st_mtimespec.tv_sec) + (Double(stat.st_mtimespec.tv_nsec) / 1_000_000_000.0)
            #endif
            return .init(
                isFolder: isFolder,
                size: numericCast(stat.st_size),
                modificationDate: Date(timeIntervalSince1970: modificationDate)
            )
        } catch {
            return nil
        }
    }

    /// Return a reponse body that will write the file body
    /// - Parameters:
    ///   - path: FileIdentifier
    ///   - context: Request context
    /// - Returns: Response body
    public func loadFile(id path: FileIdentifier, context: some RequestContext) async throws -> ResponseBody {
        try await self.fileIO.loadFile(path: path, context: context)
    }

    /// Return a reponse body that will write a partial file body
    /// - Parameters:
    ///   - path: FileIdentifier
    ///   - range: Part of file to return
    ///   - context: Request context
    /// - Returns: Response body
    public func loadFile(id path: FileIdentifier, range: ClosedRange<Int>, context: some RequestContext) async throws -> ResponseBody {
        try await self.fileIO.loadFile(path: path, range: range, context: context)
    }
}
#endif