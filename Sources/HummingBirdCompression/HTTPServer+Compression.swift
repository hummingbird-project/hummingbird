import HummingBird
import NIOHTTPCompression

extension HTTPServer {
    @discardableResult public func addRequestDecompression(limit: NIOHTTPDecompression.DecompressionLimit) -> HTTPServer {
        return self.addChildChannelHandler(NIOHTTPRequestDecompressor(limit: limit), position: .afterHTTP)
    }

    @discardableResult public func addResponseCompression(initialByteBufferCapacity: Int = 1024) -> HTTPServer {
        return self.addChildChannelHandler(
            HTTPResponseCompressor(initialByteBufferCapacity: initialByteBufferCapacity),
            position: .afterHTTP
        )
    }
}
