@testable import HummingbirdURLEncoded
import XCTest

class URLEncodedFormNodeTests: XCTestCase {
    static func XCTAssertEncodedEqual(_ lhs: String, _ rhs: String) {
        let lhs = lhs.split(separator: "&")
            .sorted { $0 < $1 }
            .joined(separator: "&")
        let rhs = rhs.split(separator: "&")
            .sorted { $0 < $1 }
            .joined(separator: "&")
        XCTAssertEqual(lhs, rhs)
    }

    func testDecodeEncode(_ string: String, encoded: URLEncodedFormNode) {
        do {
            let formData = try URLEncodedFormNode(from: string)
            XCTAssertEqual(formData, encoded)
            Self.XCTAssertEncodedEqual(formData.description, string)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testSimple() {
        let values = "one=1&two=2&three=3"
        let encoded: URLEncodedFormNode = ["one": "1", "two": "2", "three": "3"]
        testDecodeEncode(values, encoded: encoded)
    }

    func testArray() {
        let values = "array[]=1&array[]=2&array[]=3&array[]=6"
        let encoded: URLEncodedFormNode = ["array": ["1", "2", "3", "6"]]
        testDecodeEncode(values, encoded: encoded)
    }

    func testMap() {
        let values = "map[one]=1&map[two]=2&map[three]=3&map[six]=6"
        let encoded: URLEncodedFormNode = ["map": ["one": "1", "two": "2", "three": "3", "six": "6"]]
        testDecodeEncode(values, encoded: encoded)
    }

    func testMapArray() {
        let values = "map[numbers][]=1&map[numbers][]=2"
        let encoded: URLEncodedFormNode = ["map": ["numbers": ["1","2"]]]
        testDecodeEncode(values, encoded: encoded)
    }

    func testMapMap() {
        let values = "map[numbers][one]=1&map[numbers][two]=2"
        let encoded: URLEncodedFormNode = ["map": ["numbers": ["one": "1", "two": "2"]]]
        testDecodeEncode(values, encoded: encoded)
    }
}

extension URLEncodedFormNode: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .leaf(.init(value))
    }
}
extension URLEncodedFormNode: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = URLEncodedFormNode
    
    public init(dictionaryLiteral elements: (String, URLEncodedFormNode)...) {
        self = .map(.init(values: .init(elements) { first,_ in first }))
    }
}
extension URLEncodedFormNode: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: URLEncodedFormNode...) {
        self = .array(.init(values: .init(elements)))
    }
}
