import HummingbirdURLEncoded
import XCTest

class URLDecodedFormDecoderTests: XCTestCase {
    func testForm<Input: Decodable & Equatable>(_ value: Input, query: String, decoder: URLEncodedFormDecoder = .init()) {
        do {
            let value2 = try decoder.decode(Input.self, from: query)
            XCTAssertEqual(value, value2)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testSimpleStructureDecode() {
        struct Test: Codable, Equatable {
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

    func testStringSpecialCharactersDecode() {
        struct Test: Codable, Equatable {
            let a: String
        }
        let test = Test(a: "adam+!@£$%^&*()_=")
        testForm(test, query: "a=adam%2B%21%40%C2%A3%24%25%5E%26%2A%28%29_%3D")
    }

    func testContainingStructureDecode() {
        struct Test: Codable, Equatable {
            let a: Int
            let b: String
        }
        struct Test2: Codable, Equatable {
            let t: Test
        }
        let test = Test2(t: Test(a: 42, b: "Life"))
        testForm(test, query: "t[a]=42&t[b]=Life")
    }

    func testEnumDecode() {
        struct Test: Codable, Equatable {
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

    func testArrayDecode() {
        struct Test: Codable, Equatable {
            let a: [Int]
        }
        let test = Test(a: [9, 8, 7, 6])
        testForm(test, query: "a[]=9&a[]=8&a[]=7&a[]=6")
    }

    func testDictionaryDecode() {
        struct Test: Codable, Equatable {
            let a: [String: Int]
        }
        let test = Test(a: ["one": 1, "two": 2, "three": 3])
        testForm(test, query: "a[one]=1&a[three]=3&a[two]=2")
    }

    func testDateDecode() {
        struct Test: Codable, Equatable {
            let d: Date
        }
        let test = Test(d: Date(timeIntervalSinceReferenceDate: 2387643))
        testForm(test, query: "d=2387643.0")
        testForm(test, query: "d=980694843000", decoder: .init(dateDecodingStrategy: .millisecondsSince1970))
        testForm(test, query: "d=980694843", decoder: .init(dateDecodingStrategy: .secondsSince1970))
        testForm(test, query: "d=2001-01-28T15%3A14%3A03Z", decoder: .init(dateDecodingStrategy: .iso8601))

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        testForm(test, query: "d=2001-01-28T15%3A14%3A03.000Z", decoder: .init(dateDecodingStrategy: .formatted(dateFormatter)))
    }

    func testDataBlobDecode() {
        struct Test: Codable, Equatable {
            let a: Data
        }
        let data = Data("Testing".utf8)
        let test = Test(a: data)
        self.testForm(test, query: "a=VGVzdGluZw%3D%3D")
    }

    func testNestedKeyDecode() {
        struct Test: Decodable, Equatable {
            let forename: String
            let surname: String
            let age: Int
            
            init(forename: String, surname: String, age: Int) {
                self.forename = forename
                self.surname = surname
                self.age = age
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let nameContainer = try container.nestedContainer(keyedBy: NameCodingKeys.self, forKey: .name)
                self.forename = try nameContainer.decode(String.self, forKey: .forename)
                self.surname = try nameContainer.decode(String.self, forKey: .surname)
                self.age = try container.decode(Int.self, forKey: .age)
            }
            private enum CodingKeys: String, CodingKey {
                case name
                case age
            }
            private enum NameCodingKeys: String, CodingKey {
                case forename = "first"
                case surname = "second"
            }
        }
        let test = Test(forename: "John", surname: "Smith", age: 23)
        self.testForm(test, query: "name[first]=John&name[second]=Smith&age=23")
    }
}
