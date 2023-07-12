//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
        self.testURI("http://localhost:8080", \.path, "/")
        self.testURI("https://hummingbird.co.uk/users", \.path, "/users")
        self.testURI("https://hummingbird.co.uk/users?id=24", \.path, "/users")
        self.testURI("https://hummingbird.co.uk/users?", \.path, "/users")
        self.testURI("file:///Users/John.Doe/", \.path, "/Users/John.Doe/")
    }

    func testQuery() {
        self.testURI("https://hummingbird.co.uk", \.query, nil)
        self.testURI("https://hummingbird.co.uk/?test=true", \.query, "test=true")
        self.testURI("https://hummingbird.co.uk/hello?single#id", \.query, "single")
        self.testURI("https://hummingbird.co.uk/hello/?single2#id", \.query, "single2")
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.query, "test1=hello%20rg&test2=true")
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.queryParameters["test1"], "hello rg")
        self.testURI("www.mydomain.ru/search?text=банан", \.queryParameters["text"], "банан")
    }

    func testURLPerf() {
        let urlString = "https://hummingbird.co.uk/test/url?test1=hello%20rg&test2=true"
        let date = Date()
        for _ in 0..<10000 {
            _ = HBURL(urlString).queryParameters
        }
        print("\(-date.timeIntervalSinceNow)")
    }

    func testMediaTypeExtensions() {
        XCTAssert(HBMediaType.getMediaType(forExtension: "jpg")?.isType(.imageJpeg) == true)
        XCTAssert(HBMediaType.getMediaType(forExtension: "txt")?.isType(.textPlain) == true)
        XCTAssert(HBMediaType.getMediaType(forExtension: "html")?.isType(.textHtml) == true)
        XCTAssert(HBMediaType.getMediaType(forExtension: "css")?.isType(.textCss) == true)
    }

    func testMediaTypeHeaderValues() {
        XCTAssert(HBMediaType.applicationUrlEncoded.isType(.application))
        XCTAssert(HBMediaType.audioOgg.isType(.audio))
        XCTAssert(HBMediaType.videoMp4.isType(.video))
        XCTAssert(HBMediaType.fontOtf.isType(.font))
        XCTAssert(HBMediaType.multipartForm.isType(.multipart))
        XCTAssert(HBMediaType.imageSvg.isType(.image))
        XCTAssert(HBMediaType(from: "image/jpeg")?.isType(.imageJpeg) == true)
        XCTAssert(HBMediaType(from: "text/plain")?.isType(.textPlain) == true)
        XCTAssert(HBMediaType(from: "application/json")?.isType(.applicationJson) == true)
        XCTAssert(HBMediaType(from: "application/json; charset=utf8")?.isType(.applicationJson) == true)
        XCTAssert(HBMediaType(from: "application/xml")?.isType(.applicationXml) == true)
        XCTAssert(HBMediaType(from: "multipart/form-data")?.isType(.multipartForm) == true)
        XCTAssert(HBMediaType(from: "audio/ogg")?.isType(.audioOgg) == true)
    }

    func testMediaTypeMatching() {
        switch HBMediaType(from: "application/json; charset=utf8") {
        case .some(.application), .some(.applicationJson):
            break
        default: XCTFail()
        }
        switch HBMediaType(from: "application/json") {
        case .some(.application), .some(.applicationJson):
            break
        default: XCTFail()
        }
    }

    func testMediaTypeMisMatching() {
        switch HBMediaType.applicationJson {
        case HBMediaType(from: "application/json; charset=utf8")!:
            XCTFail()
        default: break
        }
        switch HBMediaType.application {
        case .applicationJson:
            XCTFail()
        default: break
        }
    }

    func testMediaTypeParameters() {
        let mediaType = HBMediaType(from: "application/json; charset=utf8")
        XCTAssertEqual(mediaType?.parameter?.name, "charset")
        XCTAssertEqual(mediaType?.parameter?.value, "utf8")
        let mediaType2 = HBMediaType(from: "multipart/form-data; boundary=\"---{}hello\"")
        XCTAssertEqual(mediaType2?.parameter?.name, "boundary")
        XCTAssertEqual(mediaType2?.parameter?.value, "---{}hello")
        let mediaType3 = HBMediaType.multipartForm.withParameter(name: "boundary", value: "----{}hello")
        XCTAssertEqual(mediaType3.parameter?.name, "boundary")
        XCTAssertEqual(mediaType3.parameter?.value, "----{}hello")
    }

    func testInvalidMediaTypes() {
        XCTAssertNil(HBMediaType(from: "application/json; charset"))
        XCTAssertNil(HBMediaType(from: "appl2ication/json"))
        XCTAssertNil(HBMediaType(from: "application/json charset=utf8"))
    }
}
