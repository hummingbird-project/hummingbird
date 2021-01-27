@testable import HummingbirdURLEncoded
import XCTest

class URLEncodedFormDataTests: XCTestCase {
    func testDecodeEncode(_ string: String, encoded: URLEncodeFormData) {
        do {
            let formData = try URLEncodeFormData(from: string)
            XCTAssertEqual(formData, encoded)
            let formDataString = formData.description
            let formData2 = try URLEncodeFormData(from: formDataString)
            XCTAssertEqual(formData, formData2)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testSimple() {
        let values = "one=1&two=2&three=3"
        let encoded: URLEncodeFormData = ["one": "1", "two": "2", "three": "3"]
        testDecodeEncode(values, encoded: encoded)
    }

    func testArray() {
        let values = "array[]=1&array[]=2&array[]=3&array[]=6"
        let encoded: URLEncodeFormData = ["array": ["1", "2", "3", "6"]]
        testDecodeEncode(values, encoded: encoded)
    }

    func testMap() {
        let values = "map[one]=1&map[two]=2&map[three]=3&map[six]=6"
        let encoded: URLEncodeFormData = ["map": ["one": "1", "two": "2", "three": "3", "six": "6"]]
        testDecodeEncode(values, encoded: encoded)
    }

    func testMapArray() {
        let values = "map[numbers][]=1&map[numbers][]=2"
        let encoded: URLEncodeFormData = ["map": ["numbers": ["1","2"]]]
        testDecodeEncode(values, encoded: encoded)
    }

    func testMapMap() {
        let values = "map[numbers][one]=1&map[numbers][two]=2"
        let encoded: URLEncodeFormData = ["map": ["numbers": ["one": "1", "two": "2"]]]
        testDecodeEncode(values, encoded: encoded)
    }
}

extension URLEncodeFormData: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .leaf(value)
    }
}
extension URLEncodeFormData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Substring, URLEncodeFormData)...) {
        self = .map(.init(values: .init(elements) { first,_ in first }))
    }
}
extension URLEncodeFormData: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: URLEncodeFormData...) {
        self = .array(.init(values: .init(elements)))
    }
}
