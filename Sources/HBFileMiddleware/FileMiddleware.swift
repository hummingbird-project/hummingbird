import HummingBird
import NIO

public struct FileMiddleware: Middleware {
    let rootFolder: String
    let fileIO: NonBlockingFileIO

    public init(_ rootFolder: String = "public/", app: Application) {
        self.rootFolder = rootFolder
        self.fileIO = .init(threadPool: app.threadPool)
    }
    
    public func apply(to request: Request, next: Responder) -> EventLoopFuture<Response> {
        // if next responder returns a 404 then check if file exists
        return next.apply(to: request).flatMapError { error in
            guard request.method == .GET else { return request.eventLoop.makeFailedFuture(error) }
            guard let httpError = error as? HTTPError, httpError.status == .notFound else {
                return request.eventLoop.makeFailedFuture(error)
            }
            
            let path = rootFolder + request.uri.path
            return fileIO.openFile(path: path, eventLoop: request.eventLoop).flatMap { handle, region in
                fileIO.read(fileHandle: handle, byteCount: region.readableBytes, allocator: request.allocator, eventLoop: request.eventLoop).map { buffer in
                    return Response(status: .ok, headers: [:], body: .byteBuffer(buffer))
                }.flatMapErrorThrowing { error in
                    try handle.close()
                    throw error
                }.flatMapThrowing { rt in
                    try handle.close()
                    return rt
                }
            }
        }
    }
}
