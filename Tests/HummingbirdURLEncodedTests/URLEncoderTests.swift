import HummingbirdURLEncoded
import XCTest

class URLEncodedFormEncoderTests: XCTestCase {
    func testForm<Input: Encodable>(_ value: Input, query: String) {
        do {
            let query2 = try URLEncodedFormEncoder().encode(value)
            XCTAssertEqual(query2, query)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testSimpleStructureEncode() {
        struct Test: Codable {
            let a: String
            let b: Int

            private enum CodingKeys: String, CodingKey {
                case a = "A"
                case b = "B"
            }
        }
        let test = Test(a: "Testing", b: 42)
        testForm(test, query: "A=Testing&B=42")
    }

    func testStringSpecialCharactersEncode() {
        struct Test: Codable {
            let a: String
        }
        let test = Test(a: "adam+!@£$%^&*()_=")
        testForm(test, query: "a=adam%2B%21%40%C2%A3%24%25%5E%26%2A%28%29_%3D")
    }

    func testContainingStructureEncode() {
        struct Test: Codable {
            let a: Int
            let b: String
        }
        struct Test2: Codable {
            let t: Test
        }
        let test = Test2(t: Test(a: 42, b: "Life"))
        testForm(test, query: "t.a=42&t.b=Life")
    }

    func testEnumEncode() {
        struct Test: Codable {
            enum TestEnum: String, Codable {
                case first
                case second
            }
            let a: TestEnum
        }
        let test = Test(a: .second)
        // NB enum names don't change to rawValue (not sure how to fix)
        testForm(test, query: "a=second")
    }

    func testArrayEncode() {
        struct Test: Codable {
            let a: [Int]
        }
        let test = Test(a: [9, 8, 7, 6])
        testForm(test, query: "a.1=9&a.2=8&a.3=7&a.4=6")
    }

    func testDictionaryEncode() {
        struct Test: Codable {
            let a: [String: Int]
        }
        let test = Test(a: ["one": 1, "two": 2, "three": 3])
        testForm(test, query: "a.one=1&a.three=3&a.two=2")
    }

    func testDataBlobEncode() {
        struct Test: Codable {
            let a: Data
        }
        let data = Data("Testing".utf8)
        let test = Test(a: data)
        self.testForm(test, query: "a=VGVzdGluZw%3D%3D")
    }
}
