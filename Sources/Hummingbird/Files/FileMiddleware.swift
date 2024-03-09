//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@preconcurrency import Foundation
import HTTPTypes
import Logging
import NIOCore
import NIOPosix

/// Middleware for serving static files.
///
/// If router returns a 404 ie a route was not found then this middleware will treat the request
/// path as a filename relative to a defined rootFolder (this defaults to "public"). It checks to see if
/// a file exists there and if so the file contents are passed back in the response.
///
/// The file middleware supports both HEAD and GET methods and supports parsing of
/// "if-modified-since", "if-none-match", "if-range" and 'range" headers. It will output "content-length",
/// "modified-date", "eTag", "content-type", "cache-control" and "content-range" headers where
/// they are relevant.
public struct HBFileMiddleware<Context: HBBaseRequestContext>: HBRouterMiddleware {
    struct IsDirectoryError: Error {}

    let rootFolder: URL
    let threadPool: NIOThreadPool
    let fileIO: HBFileIO
    let cacheControl: HBCacheControl
    let searchForIndexHtml: Bool

    /// Create HBFileMiddleware
    /// - Parameters:
    ///   - rootFolder: Root folder to look for files
    ///   - cacheControl: What cache control headers to include in response
    ///   - indexHtml: Should we look for index.html in folders
    ///   - application: Application we are attaching to
    public init(
        _ rootFolder: String = "public",
        cacheControl: HBCacheControl = .init([]),
        searchForIndexHtml: Bool = false,
        threadPool: NIOThreadPool = NIOThreadPool.singleton,
        logger: Logger = Logger(label: "HBFileMiddleware")
    ) {
        self.rootFolder = URL(fileURLWithPath: rootFolder)
        self.threadPool = threadPool
        self.fileIO = .init(threadPool: threadPool)
        self.cacheControl = cacheControl
        self.searchForIndexHtml = searchForIndexHtml

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
        logger.info("FileMiddleware serving from \(workingFolder)\(rootFolder)")
    }

    public func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
        do {
            return try await next(request, context)
        } catch {
            guard let httpError = error as? HBHTTPError, httpError.status == .notFound else {
                throw error
            }

            guard let path = request.uri.path.removingPercentEncoding else {
                throw HBHTTPError(.badRequest)
            }

            guard !path.contains("..") else {
                throw HBHTTPError(.badRequest)
            }

            let fileResult = try await self.threadPool.runIfActive { () -> FileResult in
                var fullPath = self.rootFolder.appendingPathComponent(path)

                let modificationDate: Date?
                let contentSize: Int?
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fullPath.relativePath)
                    // if file is a directory seach and `searchForIndexHtml` is set to true
                    // then search for index.html in directory
                    if let fileType = attributes[.type] as? FileAttributeType, fileType == .typeDirectory {
                        guard self.searchForIndexHtml else { throw IsDirectoryError() }
                        fullPath = fullPath.appendingPathComponent("index.html")
                        let attributes = try FileManager.default.attributesOfItem(atPath: fullPath.relativePath)
                        modificationDate = attributes[.modificationDate] as? Date
                        contentSize = attributes[.size] as? Int
                    } else {
                        modificationDate = attributes[.modificationDate] as? Date
                        contentSize = attributes[.size] as? Int
                    }
                } catch {
                    throw HBHTTPError(.notFound)
                }
                let eTag = createETag([
                    String(describing: modificationDate?.timeIntervalSince1970 ?? 0),
                    String(describing: contentSize ?? 0),
                ])

                // construct headers
                var headers = HTTPFields()

                // content-length
                if let contentSize {
                    headers[.contentLength] = String(describing: contentSize)
                }
                // modified-date
                var modificationDateString: String?
                if let modificationDate {
                    modificationDateString = HBDateCache.rfc1123Formatter.string(from: modificationDate)
                    headers[.lastModified] = modificationDateString!
                }
                // eTag (constructed from modification date and content size)
                headers[.eTag] = eTag

                // content-type
                if let extPointIndex = path.lastIndex(of: ".") {
                    let extIndex = path.index(after: extPointIndex)
                    let ext = String(path.suffix(from: extIndex))
                    if let contentType = HBMediaType.getMediaType(forExtension: ext) {
                        headers[.contentType] = contentType.description
                    }
                }

                headers[.acceptRanges] = "bytes"

                // cache-control
                if let cacheControlValue = self.cacheControl.getCacheControlHeader(for: path) {
                    headers[.cacheControl] = cacheControlValue
                }

                // verify if-none-match. No need to verify if-match as this is used for state changing
                // operations. Also the eTag we generate is considered weak.
                let ifNoneMatch = request.headers[values: .ifNoneMatch]
                if ifNoneMatch.count > 0 {
                    for match in ifNoneMatch {
                        if eTag == match {
                            return .notModified(headers)
                        }
                    }
                }
                // verify if-modified-since
                else if let ifModifiedSince = request.headers[.ifModifiedSince],
                        let modificationDate
                {
                    if let ifModifiedSinceDate = HBDateCache.rfc1123Formatter.date(from: ifModifiedSince) {
                        // round modification date of file down to seconds for comparison
                        let modificationDateTimeInterval = modificationDate.timeIntervalSince1970.rounded(.down)
                        let ifModifiedSinceDateTimeInterval = ifModifiedSinceDate.timeIntervalSince1970
                        if modificationDateTimeInterval <= ifModifiedSinceDateTimeInterval {
                            return .notModified(headers)
                        }
                    }
                }

                if let rangeHeader = request.headers[.range] {
                    guard let range = getRangeFromHeaderValue(rangeHeader) else {
                        throw HBHTTPError(.rangeNotSatisfiable)
                    }
                    // range request conditional on etag or modified date being equal to value in if-range
                    if let ifRange = request.headers[.ifRange], ifRange != headers[.eTag], ifRange != headers[.lastModified] {
                        // do nothing and drop down to returning full file
                    } else {
                        if let contentSize {
                            let lowerBound = max(range.lowerBound, 0)
                            let upperBound = min(range.upperBound, contentSize - 1)
                            headers[.contentRange] = "bytes \(lowerBound)-\(upperBound)/\(contentSize)"
                            // override content-length set above
                            headers[.contentLength] = String(describing: upperBound - lowerBound + 1)
                        }
                        return .loadFile(fullPath.relativePath, headers, range)
                    }
                }
                return .loadFile(fullPath.relativePath, headers, nil)
            }

            switch fileResult {
            case .notModified(let headers):
                return HBResponse(status: .notModified, headers: headers)
            case .loadFile(let fullPath, let headers, let range):
                switch request.method {
                case .get:
                    if let range {
                        let (body, _) = try await self.fileIO.loadFile(path: fullPath, range: range, context: context)
                        return HBResponse(status: .partialContent, headers: headers, body: body)
                    }

                    let body = try await self.fileIO.loadFile(path: fullPath, context: context)
                    return HBResponse(status: .ok, headers: headers, body: body)

                case .head:
                    return HBResponse(status: .ok, headers: headers, body: .init())

                default:
                    throw error
                }
            }
        }
    }

    /// Whether to return data from the file or a not modified response
    private enum FileResult {
        case notModified(HTTPFields)
        case loadFile(String, HTTPFields, ClosedRange<Int>?)
    }
}

extension HBFileMiddleware {
    /// Convert "bytes=value-value" range header into `ClosedRange<Int>`
    ///
    /// Also supports open ended ranges
    private func getRangeFromHeaderValue(_ header: String) -> ClosedRange<Int>? {
        let groups = self.matchRegex(header, expression: "^bytes=([\\d]*)-([\\d]*)$")
        guard groups.count == 3 else { return nil }

        if groups[1] == "" {
            guard let upperBound = Int(groups[2]) else { return nil }
            return Int.min...upperBound
        } else if groups[2] == "" {
            guard let lowerBound = Int(groups[1]) else { return nil }
            return lowerBound...Int.max
        } else {
            guard let lowerBound = Int(groups[1]),
                  let upperBound = Int(groups[2]) else { return nil }
            return lowerBound...upperBound
        }
    }

    private func matchRegex(_ string: String, expression: String) -> [Substring] {
        let nsRange = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let regularExpression = try? NSRegularExpression(pattern: expression, options: []),
              let firstMatch = regularExpression.firstMatch(in: string, range: nsRange)
        else {
            return []
        }

        var groups: [Substring] = []
        groups.reserveCapacity(firstMatch.numberOfRanges)
        for i in 0..<firstMatch.numberOfRanges {
            guard let range = Range(firstMatch.range(at: i), in: string) else { continue }
            groups.append(string[range])
        }
        return groups
    }

    private func createETag(_ strings: [String]) -> String {
        let string = strings.joined(separator: "-")
        let buffer = Array<UInt8>.init(unsafeUninitializedCapacity: 16) { bytes, size in
            var index = 0
            for i in 0..<16 {
                bytes[i] = 0
            }
            for c in string.utf8 {
                bytes[index] ^= c
                index += 1
                if index == 16 {
                    index = 0
                }
            }
            size = 16
        }

        return "W/\"\(buffer.hexDigest())\""
    }
}

extension Sequence<UInt8> {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
