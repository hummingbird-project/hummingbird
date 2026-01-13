//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import AsyncHTTPClient
import HTTPTypes
import Hummingbird
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import ServiceLifecycle
import UnixSignals

/// Test using a live server and AsyncHTTPClient as a client
final class AsyncHTTPClientTestFramework<App: ApplicationProtocol>: ApplicationTestFramework {
    struct Client: TestClientProtocol {
        let client: HTTPClient
        let urlPrefix: String
        let port: Int?
        let timeout: TimeAmount

        /// Send request and call test callback on the response returned
        func executeRequest(
            uri: String,
            method: HTTPRequest.Method,
            headers: HTTPFields = [:],
            body: ByteBuffer? = nil
        ) async throws -> TestResponse {
            let url = "\(self.urlPrefix)\(uri.first == "/" ? "" : "/")\(uri)"
            var request = HTTPClientRequest(url: url)
            request.method = .init(method)
            request.headers = .init(headers)
            request.body = body.map { .bytes($0) }
            let response = try await client.execute(request, deadline: .now() + self.timeout)
            let responseHead = HTTPResponseHead(version: response.version, status: response.status, headers: response.headers)
            return try await .init(head: .init(responseHead), body: response.body.collect(upTo: .max), trailerHeaders: nil)
        }
    }

    init(app: App, scheme: TestHTTPScheme) {
        self.timeout = .seconds(15)
        self.application = TestApplication(base: app)
        self.scheme = scheme
    }

    /// Start tests
    func run<Value>(_ test: @Sendable (Client) async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [self.application],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: self.application.logger
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }
            let port = await self.application.portPromise.wait()
            var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
            tlsConfiguration.certificateVerification = .none
            let httpClient = HTTPClient(
                eventLoopGroupProvider: .singleton,
                configuration: .init(tlsConfiguration: tlsConfiguration)
            )
            let client = Client(client: httpClient, urlPrefix: "\(self.scheme)://localhost:\(port)", port: port, timeout: self.timeout)
            do {
                let value = try await test(client)
                await serviceGroup.triggerGracefulShutdown()
                try await httpClient.shutdown()
                return value
            } catch {
                await serviceGroup.triggerGracefulShutdown()
                try await httpClient.shutdown()
                throw error
            }
        }
    }

    let application: TestApplication<App>
    let scheme: TestHTTPScheme
    let timeout: TimeAmount
}

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

private enum HTTP1TypeConversionError: Error {
    case invalidMethod
    case missingPath
    case invalidStatusCode
}

extension HTTPMethod {
    init(_ newMethod: HTTPRequest.Method) {
        switch newMethod {
        case .get: self = .GET
        case .head: self = .HEAD
        case .post: self = .POST
        case .put: self = .PUT
        case .delete: self = .DELETE
        case .connect: self = .CONNECT
        case .options: self = .OPTIONS
        case .trace: self = .TRACE
        case .patch: self = .PATCH
        default:
            let rawValue = newMethod.rawValue
            switch rawValue {
            case "ACL": self = .ACL
            case "COPY": self = .COPY
            case "LOCK": self = .LOCK
            case "MOVE": self = .MOVE
            case "BIND": self = .BIND
            case "LINK": self = .LINK
            case "MKCOL": self = .MKCOL
            case "MERGE": self = .MERGE
            case "PURGE": self = .PURGE
            case "NOTIFY": self = .NOTIFY
            case "SEARCH": self = .SEARCH
            case "UNLOCK": self = .UNLOCK
            case "REBIND": self = .REBIND
            case "UNBIND": self = .UNBIND
            case "REPORT": self = .REPORT
            case "UNLINK": self = .UNLINK
            case "MSEARCH": self = .MSEARCH
            case "PROPFIND": self = .PROPFIND
            case "CHECKOUT": self = .CHECKOUT
            case "PROPPATCH": self = .PROPPATCH
            case "SUBSCRIBE": self = .SUBSCRIBE
            case "MKCALENDAR": self = .MKCALENDAR
            case "MKACTIVITY": self = .MKACTIVITY
            case "UNSUBSCRIBE": self = .UNSUBSCRIBE
            case "SOURCE": self = .SOURCE
            default: self = .RAW(value: rawValue)
            }
        }
    }
}

extension HTTPRequest.Method {
    init(_ oldMethod: HTTPMethod) throws {
        switch oldMethod {
        case .GET: self = .get
        case .PUT: self = .put
        case .ACL: self = .init("ACL")!
        case .HEAD: self = .head
        case .POST: self = .post
        case .COPY: self = .init("COPY")!
        case .LOCK: self = .init("LOCK")!
        case .MOVE: self = .init("MOVE")!
        case .BIND: self = .init("BIND")!
        case .LINK: self = .init("LINK")!
        case .PATCH: self = .patch
        case .TRACE: self = .trace
        case .MKCOL: self = .init("MKCOL")!
        case .MERGE: self = .init("MERGE")!
        case .PURGE: self = .init("PURGE")!
        case .NOTIFY: self = .init("NOTIFY")!
        case .SEARCH: self = .init("SEARCH")!
        case .UNLOCK: self = .init("UNLOCK")!
        case .REBIND: self = .init("REBIND")!
        case .UNBIND: self = .init("UNBIND")!
        case .REPORT: self = .init("REPORT")!
        case .DELETE: self = .delete
        case .UNLINK: self = .init("UNLINK")!
        case .CONNECT: self = .connect
        case .MSEARCH: self = .init("MSEARCH")!
        case .OPTIONS: self = .options
        case .PROPFIND: self = .init("PROPFIND")!
        case .CHECKOUT: self = .init("CHECKOUT")!
        case .PROPPATCH: self = .init("PROPPATCH")!
        case .SUBSCRIBE: self = .init("SUBSCRIBE")!
        case .MKCALENDAR: self = .init("MKCALENDAR")!
        case .MKACTIVITY: self = .init("MKACTIVITY")!
        case .UNSUBSCRIBE: self = .init("UNSUBSCRIBE")!
        case .SOURCE: self = .init("SOURCE")!
        case .RAW(let value):
            guard let method = HTTPRequest.Method(value) else {
                throw HTTP1TypeConversionError.invalidMethod
            }
            self = method
        }
    }
}

extension HTTPHeaders {
    init(_ newFields: HTTPFields) {
        let fields = newFields.map { ($0.name.rawName, $0.value) }
        self.init(fields)
    }
}

extension HTTPFields {
    init(_ oldHeaders: HTTPHeaders, splitCookie: Bool) {
        self.init()
        self.reserveCapacity(count)
        var firstHost = true
        for field in oldHeaders {
            if firstHost, field.name.lowercased() == "host" {
                firstHost = false
                continue
            }
            if let name = HTTPField.Name(field.name) {
                if splitCookie, name == .cookie, #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
                    self.append(
                        contentsOf: field.value.split(separator: "; ", omittingEmptySubsequences: false).map {
                            HTTPField(name: name, value: String($0))
                        }
                    )
                } else {
                    self.append(HTTPField(name: name, value: field.value))
                }
            }
        }
    }
}

extension HTTPResponse {
    init(_ oldResponse: HTTPResponseHead) throws {
        guard oldResponse.status.code <= 999 else {
            throw HTTP1TypeConversionError.invalidStatusCode
        }
        let status = HTTPResponse.Status(code: Int(oldResponse.status.code), reasonPhrase: oldResponse.status.reasonPhrase)
        self.init(status: status, headerFields: HTTPFields(oldResponse.headers, splitCookie: false))
    }
}
