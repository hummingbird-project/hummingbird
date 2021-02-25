import Hummingbird
import XCTest

class HTTPTests: XCTestCase {
    func testURI<T: Equatable>(_ uri: HBURL, _ component: KeyPath<HBURL, T>, _ value: T) {
        XCTAssertEqual(uri[keyPath: component], value)
    }

    func testScheme() {
        self.testURI("https://hummingbird.co.uk", \.scheme, .https)
        self.testURI("/hello", \.scheme, nil)
    }

    func testHost() {
        self.testURI("https://hummingbird.co.uk", \.host, "hummingbird.co.uk")
        self.testURI("https://hummingbird.co.uk:8001", \.host, "hummingbird.co.uk")
        self.testURI("file:///Users/John.Doe/", \.host, nil)
        self.testURI("/hello", \.host, nil)
    }

    func testPort() {
        self.testURI("https://hummingbird.co.uk", \.port, nil)
        self.testURI("https://hummingbird.co.uk:8001", \.port, 8001)
        self.testURI("https://hummingbird.co.uk:80/test", \.port, 80)
    }

    func testPath() {
        self.testURI("/hello", \.path, "/hello")
        self.testURI("localhost:8080", \.path, "/")
        self.testURI("https://hummingbird.co.uk/users", \.path, "/users")
        self.testURI("https://hummingbird.co.uk/users?id=24", \.path, "/users")
        self.testURI("file:///Users/John.Doe/", \.path, "/Users/John.Doe/")
    }

    func testQuery() {
        self.testURI("https://hummingbird.co.uk", \.query, nil)
        self.testURI("https://hummingbird.co.uk?test=true", \.query, "test=true")
        self.testURI("https://hummingbird.co.uk?single#id", \.query, "single")
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.query, "test1=hello%20rg&test2=true")
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.queryParameters["test1"], "hello rg")
    }

    func testFragment() {
        self.testURI("https://hummingbird.co.uk", \.fragment, nil)
        self.testURI("https://hummingbird.co.uk?#title", \.fragment, "title")
        self.testURI("https://hummingbird.co.uk?test=false#subheading", \.fragment, "subheading")
    }

    func testMediaTypeExtensions() {
        XCTAssert(HBMediaType.getMediaType(for: "jpg")?.isType(.jpeg) == true)
        XCTAssert(HBMediaType.getMediaType(for: "txt")?.isType(.plainText) == true)
        XCTAssert(HBMediaType.getMediaType(for: "html")?.isType(.html) == true)
        XCTAssert(HBMediaType.getMediaType(for: "css")?.isType(.css) == true)
    }

    func testMediaTypeHeaderValues() {
        XCTAssert(HBMediaType(from: "image/jpeg")?.isType(.jpeg) == true)
        XCTAssert(HBMediaType(from: "text/plain")?.isType(.plainText) == true)
        XCTAssert(HBMediaType(from: "application/json")?.isType(.json) == true)
        XCTAssert(HBMediaType(from: "application/json; charset=utf8")?.isType(.json) == true)
        XCTAssert(HBMediaType(from: "application/xml")?.isType(.xml) == true)
        XCTAssert(HBMediaType(from: "audio/ogg")?.isType(.audioOgg) == true)
    }

    func testMediaTypeParameters() {
        let mediaType = HBMediaType(from: "application/json; charset=utf8")
        XCTAssertEqual(mediaType?.parameter?.name, "charset")
        XCTAssertEqual(mediaType?.parameter?.value, "utf8")
    }

    func testInvalidMediaTypes() {
        XCTAssertNil(HBMediaType(from: "application/json; charset"))
        XCTAssertNil(HBMediaType(from: "appl2ication/json"))
        XCTAssertNil(HBMediaType(from: "application/json charset=utf8"))
    }
}
