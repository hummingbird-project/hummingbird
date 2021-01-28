import Hummingbird
import XCTest

class URITests: XCTestCase {
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
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.query, "test1=hello rg&test2=true")
    }

    func testFragment() {
        self.testURI("https://hummingbird.co.uk", \.fragment, nil)
        self.testURI("https://hummingbird.co.uk?#title", \.fragment, "title")
        self.testURI("https://hummingbird.co.uk?test=false#subheading", \.fragment, "subheading")
    }
}
