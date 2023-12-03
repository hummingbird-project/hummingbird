//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
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
public struct HBFileMiddleware: HBMiddleware {
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
        application: HBApplication
    ) {
        self.rootFolder = URL(fileURLWithPath: rootFolder)
        self.threadPool = application.threadPool
        self.fileIO = .init(application: application)
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
        application.logger.info("FileMiddleware serving from \(workingFolder)\(rootFolder)")
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        struct IsDirectoryError: Error {}
        // if next responder returns a 404 then check if file exists
        let response: EventLoopFuture<HBResponse> = next.respond(to: request)
        return response.flatMapError { error -> EventLoopFuture<HBResponse> in
            guard let httpError = error as? HBHTTPError, httpError.status == .notFound else {
                return request.failure(error)
            }

            guard let path = request.uri.path.removingPercentEncoding else {
                return request.failure(.badRequest)
            }

            guard !path.contains("..") else {
                return request.failure(.badRequest)
            }

            var fullPath = self.rootFolder.appendingPathComponent(path)

            return self.threadPool.runIfActive(eventLoop: request.eventLoop) { () -> FileResult in
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
                var headers = HTTPHeaders()

                // content-length
                if let contentSize = contentSize {
                    headers.add(name: "content-length", value: String(describing: contentSize))
                }
                // modified-date
                var modificationDateString: String?
                if let modificationDate = modificationDate {
                    modificationDateString = HBDateCache.rfc1123Formatter.string(from: modificationDate)
                    headers.add(name: "modified-date", value: modificationDateString!)
                }
                // eTag (constructed from modification date and content size)
                headers.add(name: "eTag", value: eTag)

                // content-type
                if let contentType = HBMediaType.getMediaType(forExtension: fullPath.pathExtension) {
                    headers.add(name: "content-type", value: contentType.description)
                }

                headers.replaceOrAdd(name: "accept-ranges", value: "bytes")

                // cache-control
                if let cacheControlValue = self.cacheControl.getCacheControlHeader(for: path) {
                    headers.add(name: "cache-control", value: cacheControlValue)
                }

                // verify if-none-match. No need to verify if-match as this is used for state changing
                // operations. Also the eTag we generate is considered weak.
                let ifNoneMatch = request.headers["if-none-match"]
                if ifNoneMatch.count > 0 {
                    for match in ifNoneMatch {
                        if eTag == match {
                            return .notModified(headers)
                        }
                    }
                }
                // verify if-modified-since
                else if let ifModifiedSince = request.headers["if-modified-since"].first,
                        let modificationDate = modificationDate
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

                if let rangeHeader = request.headers["Range"].first {
                    guard let range = getRangeFromHeaderValue(rangeHeader) else {
                        throw HBHTTPError(.rangeNotSatisfiable)
                    }
                    // range request conditional on etag or modified date being equal to value in if-range
                    if let ifRange = request.headers["if-range"].first, ifRange != headers["eTag"].first, ifRange != headers["modified-date"].first {
                        // do nothing and drop down to returning full file
                    } else {
                        if let contentSize = contentSize {
                            let lowerBound = max(range.lowerBound, 0)
                            let upperBound = min(range.upperBound, contentSize - 1)
                            headers.replaceOrAdd(name: "content-range", value: "bytes \(lowerBound)-\(upperBound)/\(contentSize)")
                            // override content-length set above
                            headers.replaceOrAdd(name: "content-length", value: String(describing: upperBound - lowerBound + 1))
                        }
                        return .loadFile(headers, range)
                    }
                }
                return .loadFile(headers, nil)
            }.flatMap { (result: FileResult) -> EventLoopFuture<HBResponse> in
                switch result {
                case .notModified(let headers):
                    return request.eventLoop.makeSucceededFuture(HBResponse(status: .notModified, headers: headers))
                case .loadFile(let headers, let range):
                    switch request.method {
                    case .GET:
                        if let range = range {
                            return self.fileIO.loadFile(path: fullPath.relativePath, range: range, context: request.context, logger: request.logger)
                                .map { body, _ in
                                    return HBResponse(status: .partialContent, headers: headers, body: body)
                                }
                        }
                        return self.fileIO.loadFile(path: fullPath.relativePath, context: request.context, logger: request.logger)
                            .map { body in
                                return HBResponse(status: .ok, headers: headers, body: body)
                            }

                    case .HEAD:
                        return request.success(HBResponse(status: .ok, headers: headers, body: .empty))

                    default:
                        return request.failure(error)
                    }
                }
            }
        }
    }

    /// Whether to return data from the file or a not modified response
    private enum FileResult {
        case notModified(HTTPHeaders)
        case loadFile(HTTPHeaders, ClosedRange<Int>?)
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

extension Sequence where Element == UInt8 {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
