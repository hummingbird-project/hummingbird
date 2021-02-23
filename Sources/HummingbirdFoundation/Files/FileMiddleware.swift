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
                return request.eventLoop.makeFailedFuture(error)
            }

            guard let path = request.uri.path.removingPercentEncoding else {
                return request.eventLoop.makeFailedFuture(HBHTTPError(.badRequest))
            }

            guard !path.contains("..") else {
                return request.eventLoop.makeFailedFuture(HBHTTPError(.badRequest))
            }

            let fullPath = rootFolder + path

            switch request.method {
            case .GET:
                var range: ClosedRange<Int>?
                if let rangeHeader = request.headers["Range"].first {
                    range = getRangeFromHeaderValue(rangeHeader)
                }
                return fileIO.loadFile(path: fullPath, range: range, context: request.context)
                    .map { body, fileSize in
                        var headers: HTTPHeaders = [:]
                        if let range = range {
                            let lowerBound = max(range.lowerBound, 0)
                            let upperBound = min(range.upperBound, fileSize - 1)
                            headers.replaceOrAdd(name: "content-range", value: "bytes \(lowerBound)-\(upperBound)/\(fileSize)")
                        }
                        return HBResponse(status: .ok, headers: headers, body: body)
                    }

            case .HEAD:
                return fileIO.headFile(path: fullPath, context: request.context)

            default:
                return request.eventLoop.makeFailedFuture(error)
            }
        }
    }
}

extension HBFileMiddleware {
    /// Convert "bytes=value-value" range header into `ClosedRange<Int>`
    ///
    /// Also supports open ended ranges
    func getRangeFromHeaderValue(_ header: String) -> ClosedRange<Int>? {
        let scanner = Scanner(string: header)
        guard scanner.scanString("bytes=") == "bytes=" else { return nil }
        let position = scanner.currentIndex
        let char = scanner.scanCharacter()
        if char == "-" {
            guard let upperBound = scanner.scanInt() else { return nil }
            return Int.min...upperBound
        }
        scanner.currentIndex = position
        guard let lowerBound = scanner.scanInt() else { return nil }
        guard scanner.scanCharacter() == "-" else { return nil }
        if scanner.isAtEnd {
            return lowerBound...Int.max
        }
        guard let upperBound = scanner.scanInt() else { return nil }
        guard upperBound >= lowerBound else { return nil }
        return lowerBound...upperBound
    }
}
