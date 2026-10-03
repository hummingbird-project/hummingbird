//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#if FileSystemSupport
public import Logging
public import NIOPosix
import _NIOFileSystem
import SystemPackage

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

    let rootFolder: FilePath
    let fileIO: FileIO

    /// Initialize LocalFileSystem FileProvider
    /// - Parameters:
    ///   - rootFolder: Root folder to serve files from
    ///   - threadPool: Thread pool used when loading files
    ///   - logger: Logger to output root folder information
    public init(rootFolder: String, threadPool: NIOThreadPool, logger: Logger) {
        self.rootFolder = FilePath(rootFolder)
        self.fileIO = .init(threadPool: threadPool)

        let absolutePath: FilePath
        if self.rootFolder.isAbsolute {
            absolutePath = self.rootFolder
        } else {
            if let cwd = getcwd(nil, 0) {
                absolutePath = FilePath(platformString: cwd).pushing(self.rootFolder)
                free(cwd)
            } else {
                absolutePath = self.rootFolder
            }
        }
        logger.info("Serving files from \(absolutePath)")
    }

    /// Get full path name with local file system root prefixed
    /// - Parameter path: path from URI
    /// - Returns: Full path
    public func getFileIdentifier(_ path: String) -> FileIdentifier? {
        let fullPath = self.rootFolder.appending(path).string
        return fullPath
    }

    /// Get file attributes
    /// - Parameter path: FileIdentifier
    /// - Returns: File attributes
    public func getAttributes(id path: FileIdentifier) async throws -> FileAttributes? {
        do {
            guard let info = try await self.fileIO.fileSystem.info(forFileAt: .init(path)) else { throw FileIO.FileError.fileDoesNotExist }
            let isFolder = info.type == .directory
            let modificationDate = Double(info.lastDataModificationTime.seconds)
            return .init(
                isFolder: isFolder,
                size: numericCast(info.size),
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
