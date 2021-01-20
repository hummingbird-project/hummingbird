#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Foundation
import Hummingbird
import NIO

public struct FileMiddleware: Middleware {
    let rootFolder: String
    let fileIO: FileIO

    public init(_ rootFolder: String = "public", application: Application) {
        var rootFolder = rootFolder
        if rootFolder.last == "/" {
            rootFolder = String(rootFolder.dropLast())
        }
        self.rootFolder = rootFolder
        self.fileIO = .init(application: application)

        let workingFolder: String
        if let cwd = getcwd(nil, Int(PATH_MAX)) {
            workingFolder = String(cString: cwd)
            free(cwd)
        } else {
            workingFolder = "./"
        }
        defer {
            application.logger.info("FileMiddleware serving from \(workingFolder)")
        }

    }

    public func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response> {
        // if next responder returns a 404 then check if file exists
        return next.respond(to: request).flatMapError { error in
            guard let httpError = error as? HTTPError, httpError.status == .notFound else {
                return request.eventLoop.makeFailedFuture(error)
            }

            guard let path = request.uri.path.removingPercentEncoding else {
                return request.eventLoop.makeFailedFuture(HTTPError(.badRequest))
            }

            guard !path.contains("..") else {
                return request.eventLoop.makeFailedFuture(HTTPError(.badRequest))
            }

            let fullPath = rootFolder + path

            switch request.method {
            case .GET:
                return fileIO.loadFile(for: request, path: fullPath)

            case .HEAD:
                return fileIO.headFile(for: request, path: fullPath)

            default:
                return request.eventLoop.makeFailedFuture(error)
            }
        }
    }
}
