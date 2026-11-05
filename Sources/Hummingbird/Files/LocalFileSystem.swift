//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import Logging
public import NIOPosix
import SystemPackage
import _NIOFileSystem

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
    // Local file system options
    public struct Options: OptionSet, Sendable {
        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Allow file provider to follow symbolic links
        public static var allowSymbolicLinks: Self { .init(rawValue: 1 << 0) }
    }

    // TODO: Change this to FilePath when we can afford the breaking change
    /// File Identifier (Fully qualified path)
    public typealias FileIdentifier = String

    let rootFolder: FilePath
    let fileIO: FileIO
    let options: Options

    /// Initialize LocalFileSystem FileProvider
    /// - Parameters:
    ///   - rootFolder: Root folder to serve files from
    ///   - options: Options for local file system file provider
    ///   - threadPool: Thread pool used when loading files
    ///   - logger: Logger to output root folder information
    public init(rootFolder: String, options: Options, threadPool: NIOThreadPool = .singleton, logger: Logger) {
        self.rootFolder = .init(rootFolder)
        self.fileIO = .init(threadPool: threadPool)
        self.options = options

        let absoluteRootFolder: FilePath
        if self.rootFolder.isAbsolute {
            absoluteRootFolder = self.rootFolder
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            if !cwd.isEmpty {
                absoluteRootFolder = FilePath(cwd).appending(self.rootFolder.components)
            } else {
                absoluteRootFolder = self.rootFolder
            }
        }
        logger.info("Serving files from \(absoluteRootFolder)")
    }

    /// Initialize LocalFileSystem FileProvider
    /// - Parameters:
    ///   - rootFolder: Root folder to serve files from
    ///   - threadPool: Thread pool used when loading files
    ///   - logger: Logger to output root folder information
    public init(rootFolder: String, threadPool: NIOThreadPool = .singleton, logger: Logger) {
        self.init(rootFolder: rootFolder, options: [], threadPool: threadPool, logger: logger)
    }

    /// Get full path name with local file system root prefixed
    /// - Parameter path: path from URI
    /// - Returns: Full path
    public func getFileIdentifier(_ path: String) -> FileIdentifier? {
        self.rootFolder.lexicallyResolving(FilePath(path))?.string
    }

    /// Get file attributes
    /// - Parameter path: FileIdentifier
    /// - Returns: File attributes
    public func getAttributes(id path: FileIdentifier) async throws -> FileAttributes? {
        do {
            guard
                let info = try await self.fileIO.fileSystem.info(
                    forFileAt: .init(path),
                    infoAboutSymbolicLink: !self.options.contains(.allowSymbolicLinks)
                )
            else { throw FileIO.FileError.fileDoesNotExist }
            // only allow symbolic links if options allow for them
            guard info.type != .symlink else { return nil }
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
