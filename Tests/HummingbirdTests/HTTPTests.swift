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

import Foundation
import Hummingbird
import HummingbirdCore
import Testing

struct HTTPTests {
    func testURI<T: Equatable>(_ uri: URI, _ component: KeyPath<URI, T>, _ value: T) {
        #expect(uri[keyPath: component] == value)
    }

    @Test func testScheme() {
        self.testURI("https://hummingbird.co.uk", \.scheme, .https)
        self.testURI("/hello", \.scheme, nil)
    }

    @Test func testHost() {
        self.testURI("https://hummingbird.co.uk", \.host, "hummingbird.co.uk")
        self.testURI("https://hummingbird.co.uk:8001", \.host, "hummingbird.co.uk")
        self.testURI("file:///Users/John.Doe/", \.host, nil)
        self.testURI("/hello", \.host, nil)
    }

    @Test func testPort() {
        self.testURI("https://hummingbird.co.uk", \.port, nil)
        self.testURI("https://hummingbird.co.uk:8001", \.port, 8001)
        self.testURI("https://hummingbird.co.uk:80/test", \.port, 80)
    }

    @Test func testPath() {
        self.testURI("/hello", \.path, "/hello")
        self.testURI("http://localhost:8080", \.path, "/")
        self.testURI("https://hummingbird.co.uk/users", \.path, "/users")
        self.testURI("https://hummingbird.co.uk/users?id=24", \.path, "/users")
        self.testURI("https://hummingbird.co.uk/users?", \.path, "/users")
        self.testURI("file:///Users/John.Doe/", \.path, "/Users/John.Doe/")
    }

    @Test func testQuery() {
        self.testURI("https://hummingbird.co.uk", \.query, nil)
        self.testURI("https://hummingbird.co.uk/?test=true", \.query, "test=true")
        self.testURI("https://hummingbird.co.uk/hello?single#id", \.query, "single")
        self.testURI("https://hummingbird.co.uk/hello/?single2#id", \.query, "single2")
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.query, "test1=hello%20rg&test2=true")
        self.testURI("https://hummingbird.co.uk?test1=hello%20rg&test2=true", \.queryParameters["test1"], "hello rg")
        self.testURI("www.mydomain.ru/search?text=банан", \.queryParameters["text"], "банан")
    }

    @Test func testURLPerf() {
        let urlString = "https://hummingbird.co.uk/test/url?test1=hello%20rg&test2=true"
        let date = Date()
        for _ in 0..<10000 {
            _ = URI(urlString).queryParameters
        }
        print("\(-date.timeIntervalSinceNow)")
    }

    @Test func testMediaTypeExtensions() {
        #expect(MediaType.getMediaType(forExtension: "jpg")?.isType(.imageJpeg) == true)
        #expect(MediaType.getMediaType(forExtension: "txt")?.isType(.textPlain) == true)
        #expect(MediaType.getMediaType(forExtension: "html")?.isType(.textHtml) == true)
        #expect(MediaType.getMediaType(forExtension: "css")?.isType(.textCss) == true)
    }

    @Test func testMediaTypeHeaderValues() {
        #expect(MediaType.applicationUrlEncoded.isType(.application))
        #expect(MediaType.audioOgg.isType(.audio))
        #expect(MediaType.videoMp4.isType(.video))
        #expect(MediaType.fontOtf.isType(.font))
        #expect(MediaType.multipartForm.isType(.multipart))
        #expect(MediaType.imageSvg.isType(.image))
        #expect(MediaType(from: "image/jpeg")?.isType(.imageJpeg) == true)
        #expect(MediaType(from: "text/plain")?.isType(.textPlain) == true)
        #expect(MediaType(from: "application/json")?.isType(.applicationJson) == true)
        #expect(MediaType(from: "application/json; charset=utf8")?.isType(.applicationJson) == true)
        #expect(MediaType(from: "application/xml")?.isType(.applicationXml) == true)
        #expect(MediaType(from: "multipart/form-data")?.isType(.multipartForm) == true)
        #expect(MediaType(from: "audio/ogg")?.isType(.audioOgg) == true)
    }

    @Test func testMediaTypeMatching() {
        switch MediaType(from: "application/json; charset=utf8") {
        case .some(.application), .some(.applicationJson):
            break
        default: Issue.record()
        }
        switch MediaType(from: "application/json") {
        case .some(.application), .some(.applicationJson):
            break
        default: Issue.record()
        }
    }

    @Test func testMediaTypeMisMatching() {
        switch MediaType.applicationJson {
        case MediaType(from: "application/json; charset=utf8")!:
            Issue.record()
        default: break
        }
        switch MediaType.application {
        case .applicationJson:
            Issue.record()
        default: break
        }
    }

    @Test func testMediaTypeParameters() {
        let mediaType = MediaType(from: "application/json; charset=utf8")
        #expect(mediaType?.parameter?.name == "charset")
        #expect(mediaType?.parameter?.value == "utf8")
        let mediaType2 = MediaType(from: "multipart/form-data; boundary=\"---{}hello\"")
        #expect(mediaType2?.parameter?.name == "boundary")
        #expect(mediaType2?.parameter?.value == "---{}hello")
        let mediaType3 = MediaType.multipartForm.withParameter(name: "boundary", value: "----{}hello")
        #expect(mediaType3.parameter?.name == "boundary")
        #expect(mediaType3.parameter?.value == "----{}hello")
    }

    @Test func testInvalidMediaTypes() {
        #expect(MediaType(from: "application/json; charset") == nil)
        #expect(MediaType(from: "appl2ication/json") == nil)
        #expect(MediaType(from: "application/json charset=utf8") == nil)
    }

    @Test func testMediaTypeEncoding() throws {
        let mediaType = MediaType.applicationJson.withParameter(name: "charset", value: "utf8")
        let encoded = try JSONEncoder().encode(mediaType)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        #expect(encodedString == "\"application\\/json; charset=utf8\"")
    }

    @Test func testMediaTypeDecoding() throws {
        let data = Data("\"application/json; charset=utf8\"".utf8)
        let mediaType = try JSONDecoder().decode(MediaType.self, from: data)
        #expect(mediaType.type == .application)
        #expect(mediaType.subType == "json")
        #expect(mediaType.parameter?.name == "charset")
        #expect(mediaType.parameter?.value == "utf8")
    }
}
