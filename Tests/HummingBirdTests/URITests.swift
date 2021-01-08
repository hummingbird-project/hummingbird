import HummingBird
import XCTest

class URITests: XCTestCase {
    func testURI<T: Equatable>(_ uri: URI, _ component: KeyPath<URI, T>, _ value: T) {
        XCTAssertEqual(uri[keyPath: component], value)
    }

    func testScheme() {
        testURI("https://hummingbird.co.uk", \.scheme, .https)
        testURI("/hello", \.scheme, nil)
    }

    func testHost() {
        testURI("https://hummingbird.co.uk", \.host, "hummingbird.co.uk")
        testURI("https://hummingbird.co.uk:8001", \.host, "hummingbird.co.uk")
        testURI("file:///Users/John.Doe/", \.host, nil)
        testURI("/hello", \.host, nil)
    }

    func testPort() {
        testURI("https://hummingbird.co.uk", \.port, nil)
        testURI("https://hummingbird.co.uk:8001", \.port, 8001)
        testURI("https://hummingbird.co.uk:80/test", \.port, 80)
    }

    func testPath() {
        testURI("/hello", \.path, "/hello")
        testURI("localhost:8080", \.path, "/")
        testURI("https://hummingbird.co.uk/users", \.path, "/users")
        testURI("https://hummingbird.co.uk/users?id=24", \.path, "/users")
        testURI("file:///Users/John.Doe/", \.path, "/Users/John.Doe/")
    }

    func testQuery() {
        testURI("https://hummingbird.co.uk", \.query, nil)
        testURI("https://hummingbird.co.uk?test=true", \.query, "test=true")
        testURI("https://hummingbird.co.uk?single#id", \.query, "single")
        testURI("https://hummingbird.co.uk?test1=hello%rg&test2=true", \.query, "test1=hello%rg&test2=true")
    }

    func testFragment() {
        testURI("https://hummingbird.co.uk", \.fragment, nil)
        testURI("https://hummingbird.co.uk?#title", \.fragment, "title")
        testURI("https://hummingbird.co.uk?test=false#subheading", \.fragment, "subheading")
    }
}
