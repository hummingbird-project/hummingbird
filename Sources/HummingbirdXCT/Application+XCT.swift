import Hummingbird
import NIO
import NIOHTTP1
import XCTest

extension HBApplication {
    /// Test setup
    public enum XCTTestingSetup {
        /// test using EmbeddedChannel. If you have routes that use multi-threading this will probably fail
        case embedded
        /// test using live server
        case live
    }

    /// Initialization for when testing
    /// - Parameters:
    ///   - testing: indicate we are testing
    ///   - configuration: configuration
    public convenience init(testing: XCTTestingSetup, configuration: HBApplication.Configuration = .init()) {
        let xct: HBXCT
        switch testing {
        case .embedded:
            xct = HBXCTEmbedded()
        case .live:
            xct = HBXCTLive(configuration: configuration)
        }
        self.init(configuration: configuration, eventLoopGroupProvider: .shared(xct.eventLoopGroup))
        self.extensions.set(\.xct, value: xct)
    }

    public var xct: HBXCT {
        self.extensions.get(\.xct)
    }

    /// Start tests
    public func XCTStart() {
        self.xct.start(application: self)
    }

    /// Stop tests
    public func XCTStop() {
        self.xct.stop(application: self)
    }

    /// Send request and call test callback on the response returned
    public func XCTExecute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        testCallback: @escaping (HBXCTResponse) throws -> Void
    ) {
        XCTAssertNoThrow(try self.xct.execute(uri: uri, method: method, headers: headers, body: body).flatMapThrowing { response in
            try testCallback(response)
        }.wait())
    }
}
