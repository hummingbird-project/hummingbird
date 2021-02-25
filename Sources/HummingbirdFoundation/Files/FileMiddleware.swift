#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Foundation
import Hummingbird
import NIO

public struct HBFileMiddleware: HBMiddleware {
    let rootFolder: String
    let fileIO: HBFileIO

    public init(_ rootFolder: String = "public", application: HBApplication) {
        var rootFolder = rootFolder
        if rootFolder.last == "/" {
            rootFolder = String(rootFolder.dropLast())
        }
        self.rootFolder = rootFolder
        self.fileIO = .init(application: application)

        let workingFolder: String
        if rootFolder.first == "/" {
            workingFolder = rootFolder
        } else {
            if let cwd = getcwd(nil, Int(PATH_MAX)) {
                workingFolder = String(cString: cwd)
                free(cwd)
            } else {
                workingFolder = "."
            }
        }
        application.logger.info("FileMiddleware serving from \(workingFolder)/\(rootFolder)")
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        // if next responder returns a 404 then check if file exists
        return next.respond(to: request).flatMapError { error in
            guard let httpError = error as? HBHTTPError, httpError.status == .notFound else {
                return request.failure(error)
            }

            guard let path = request.uri.path.removingPercentEncoding else {
                return request.failure(.badRequest)
            }

            guard !path.contains("..") else {
                return request.failure(.badRequest)
            }

            let fullPath = rootFolder + path
            let modificationDate: Date?
            let contentSize: Int?
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fullPath)
                modificationDate = attributes[.modificationDate] as? Date
                contentSize = attributes[.size] as? Int
            } catch {
                return request.failure(.notFound)
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
            if let modificationDate = modificationDate {
                headers.add(name: "modified-date", value: HBDateCache.rfc1123Formatter.string(from: modificationDate))
            }
            // eTag (constructed from modification date and content size)
            headers.add(name: "eTag", value: eTag)

            // verify if-none-match. No need to verify if-match as this is used for state changing
            // operations. Also the eTag we generate is considered weak.
            let ifNoneMatch = request.headers["if-none-match"]
            if ifNoneMatch.count > 0 {
                for match in ifNoneMatch {
                    if eTag == match {
                        return request.success(HBResponse(status: .notModified, headers: headers))
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
                        return request.success(HBResponse(status: .notModified, headers: headers))
                    }
                }
            }

            // content-type
            if let extPointIndex = path.lastIndex(of: ".") {
                let extIndex = path.index(after: extPointIndex)
                if let contentType = HBMediaType.getMediaType(for: String(path.suffix(from: extIndex))) {
                    headers.add(name: "content-type", value: contentType.description)
                }
            }

            switch request.method {
            case .GET:
                if let rangeHeader = request.headers["Range"].first {
                    guard let range = getRangeFromHeaderValue(rangeHeader) else {
                        return request.failure(.rangeNotSatisfiable)
                    }
                    return fileIO.loadFile(path: fullPath, range: range, context: request.context)
                        .map { body, fileSize in
                            headers.replaceOrAdd(name: "accept-ranges", value: "bytes")

                            let lowerBound = max(range.lowerBound, 0)
                            let upperBound = min(range.upperBound, fileSize - 1)
                            headers.replaceOrAdd(name: "content-range", value: "bytes \(lowerBound)-\(upperBound)/\(fileSize)")
                            // override content-length set above
                            headers.replaceOrAdd(name: "content-length", value: String(describing: upperBound - lowerBound + 1))

                            return HBResponse(status: .partialContent, headers: headers, body: body)
                        }
                }
                return fileIO.loadFile(path: fullPath, context: request.context)
                    .map { body in
                        headers.replaceOrAdd(name: "accept-ranges", value: "bytes")
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
        guard let regularExpression = try? NSRegularExpression(pattern: expression, options: []),
              let firstMatch = regularExpression.firstMatch(in: string, range: NSMakeRange(0, string.count))
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
