import HummingbirdURLEncoded
import XCTest

class URLEncodedFormEncoderTests: XCTestCase {
    func testForm<Input: Encodable>(_ value: Input, query: String, encoder: URLEncodedFormEncoder = .init()) {
        do {
            let query2 = try encoder.encode(value)
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
        testForm(test, query: "t[a]=42&t[b]=Life")
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
        testForm(test, query: "a[]=9&a[]=8&a[]=7&a[]=6")
    }

    func testDictionaryEncode() {
        struct Test: Codable {
            let a: [String: Int]
        }
        let test = Test(a: ["one": 1, "two": 2, "three": 3])
        testForm(test, query: "a[one]=1&a[three]=3&a[two]=2")
    }

    func testDateEncode() {
        struct Test: Codable {
            let d: Date
        }
        let test = Test(d: Date(timeIntervalSinceReferenceDate: 2387643))
        testForm(test, query: "d=2387643.0")
        testForm(test, query: "d=980694843000", encoder: .init(dateEncodingStrategy: .millisecondsSince1970))
        testForm(test, query: "d=980694843", encoder: .init(dateEncodingStrategy: .secondsSince1970))
        testForm(test, query: "d=2001-01-28T15%3A14%3A03Z", encoder: .init(dateEncodingStrategy: .iso8601))

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        testForm(test, query: "d=2001-01-28T15%3A14%3A03.000Z", encoder: .init(dateEncodingStrategy: .formatted(dateFormatter)))
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
