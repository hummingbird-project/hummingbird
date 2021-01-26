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

    var xct: HBXCT {
        self.extensions.get(\.xct)
    }

    /// Start tests
    public func XCTStart() {
        xct.start(application: self)
    }

    /// Stop tests
    public func XCTStop() {
        // get XCT so we can ensure it is shutdown last
        let xct = self.xct
        try? self.shutdownApplication()
        xct.stop()
    }

    /// Send request and call test callback on the response returned
    public func XCTExecute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        testCallback: @escaping (HBXCTResponse) throws -> ()
    ) {
        XCTAssertNoThrow(try xct.execute(uri: uri, method: method, headers: headers, body: body).flatMapThrowing { response in
            try testCallback(response)
        }.wait())
    }
}
