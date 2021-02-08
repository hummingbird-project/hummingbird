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

    /// This creates a version of `HBApplication` that can be used for testing code
    ///
    /// You use `XCTStart`, `XCTStop` and `XCTExecute` to run test applications. The example below
    /// is using the `.embedded` framework to test
    /// ```
    /// let app = HBApplication(testing: .embedded)
    /// app.router.get("/hello") { _ in
    ///     return "hello"
    /// }
    /// app.XCTStart()
    /// defer { app.XCTStop() }
    ///
    /// // does my app return "hello" in the body for this route
    /// app.XCTExecute(uri: "/hello", method: .GET) { response in
    ///     let body = try XCTUnwrap(response.body)
    ///     XCTAssertEqual(String(buffer: body, "hello")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - testing: indicates which type of testing framework we want
    ///   - configuration: configuration of application
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
