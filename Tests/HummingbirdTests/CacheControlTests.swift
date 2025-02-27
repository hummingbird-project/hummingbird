import Hummingbird
import XCTest

final class CacheControlTests: XCTestCase {
    func testCssIsText() {
        let cacheControl = CacheControl([
			(MediaType(type: .text), [.noCache, .public]),
		])
        XCTAssertEqual(cacheControl.getCacheControlHeader(for: "test.css"), "no-cache, public")
    }

    func testMultipleEntries() {
        let cacheControl = CacheControl([
			(MediaType.textCss, [.noStore]),
			(MediaType.text, [.noCache, .public]),
		])
        XCTAssertEqual(cacheControl.getCacheControlHeader(for: "test.css"), "no-store")
    }

    func testCssIsAny() {
        let cacheControl = CacheControl([
			(MediaType(type: .any), [.noCache, .public]),
		])
        XCTAssertEqual(cacheControl.getCacheControlHeader(for: "test.css"), "no-cache, public")
    }
}
