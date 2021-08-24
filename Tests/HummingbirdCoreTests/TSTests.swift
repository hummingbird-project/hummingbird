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

#if canImport(Network)

import HummingbirdCore
import HummingbirdCoreXCT
import Logging
import Network
import NIO
import NIOHTTP1
import NIOSSL
import NIOTransportServices
import XCTest

@available(macOS 10.14, iOS 12, tvOS 12, *)
class TransportServicesTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    struct HelloResponder: HBHTTPResponder {
        func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
            let responseBody = context.channel.allocator.buffer(string: "Hello")
            let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
            onComplete(.success(response))
        }
    }

    func testConnect() {
        let eventLoopGroup = NIOTSEventLoopGroup()
        let server = HBHTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get("/").flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testTLS() throws {
        let eventLoopGroup = NIOTSEventLoopGroup()
        let p12Path = Bundle.module.path(forResource: "server", ofType: "p12")!
        let tlsOptions = try XCTUnwrap(TSTLSOptions.options(
            serverIdentity: .p12(filename: p12Path, password: "MyPassword")
        ))
        let configuration = HBHTTPServer.Configuration(
            address: .hostname(port: 0),
            tlsOptions: tlsOptions
        )
        let server = HBHTTPServer(group: eventLoopGroup, configuration: configuration)
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = try HBXCTClient(
            host: "localhost",
            port: server.port!,
            configuration: .init(tlsConfiguration: self.getClientTLSConfiguration()),
            eventLoopGroupProvider: .createNew
        )
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get("/").flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
    }

    let caCertificateData = """
    -----BEGIN CERTIFICATE-----
    MIIDajCCAlICCQDKUlXSE51o8zANBgkqhkiG9w0BAQsFADB3MQswCQYDVQQGEwJV
    SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxFDASBgNV
    BAoMC0h1bW1pbmdiaXJkMRYwFAYDVQQLDA1IdW1taW5nYmlyZENBMRIwEAYDVQQD
    DAlsb2NhbGhvc3QwHhcNMjEwMTEyMTkwMDI5WhcNMjIwMTEyMTkwMDI5WjB3MQsw
    CQYDVQQGEwJVSzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVy
    Z2gxFDASBgNVBAoMC0h1bW1pbmdiaXJkMRYwFAYDVQQLDA1IdW1taW5nYmlyZENB
    MRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
    AoIBAQC/iOKVn0sfT5Uu1XoIt7GMG2gEwHSFJ4taHUbV6AuZmey5wA6fbrgaBKY7
    fEc/vakjSH3evQJD+Bj2ZIdfKmt08iRe/9tC3Gyu4SvDC3wWLT1RQ65JR4LAxV4D
    eX1x4zLzz23XxI90EbJ0QFGz+VLdcPucLeWQmtfJkt8f0utQKKUUQbXtBhmBT20x
    rzt3NVvCTAYNWb0qK0XBz4pHv1hCyIKlpqBt98aXVKbhaDmCa/8VhsnVdb7Nuur+
    ytmdJGlFGzhOvfBI2o/NAhvAIef2rVCSe3DybJ6y7I7818othD8x0LNXRr9xajel
    HnphQF2vY/+h/WmR1oBahT5AxJppAgMBAAEwDQYJKoZIhvcNAQELBQADggEBACOV
    MVEFCC6yhQTleetrpRBjqvmMqJKNKhJK/wwRXDsnH9KfONfnyqUG11zA6x0s5fHN
    ML3MIVY5AjvaCwki3lq5tDO0sZId3kbgFq67MfYxoOjgODkmSnP5qW2+0R5pTZCp
    vRt8c7y9pzPhXL6d1RiC3E+wdtEx3vUFTLWXpBbn7d/kV5QL3vmnAcOTeaBnBnxy
    pv9Os0lEZT/Nyp8Zjwg7BeOIwde/tteiymRtW5hOb46FsDF8JL31nG5cXN3C2+eU
    iAffbMvu+ie1nmAkMMP0PuWNCEzWr9eV8ov/GPd7c6s2AiTXGSh78+U0kUJeARLl
    8YLI1W2Om/RI0w/GbeY=
    -----END CERTIFICATE-----
    """

    let clientCertificateData = """
    -----BEGIN CERTIFICATE-----
    MIIDaDCCAlACCQCyf57lM8EAnTANBgkqhkiG9w0BAQsFADB3MQswCQYDVQQGEwJV
    SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxFDASBgNV
    BAoMC0h1bW1pbmdiaXJkMRYwFAYDVQQLDA1IdW1taW5nYmlyZENBMRIwEAYDVQQD
    DAlsb2NhbGhvc3QwHhcNMjEwMTEyMTkwMDI5WhcNMjIwMTEyMTkwMDI5WjB1MQsw
    CQYDVQQGEwJVSzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVy
    Z2gxFDASBgNVBAoMC0h1bW1pbmdiaXJkMRQwEgYDVQQLDAtIdW1taW5nYmlyZDES
    MBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
    AQEA+tJcxLe5buNsMgLwyF7Y3x6cV5ytmqSAC1hPXzBi8ax6/BT2oW+fvBxCVT/s
    n3TsKUSn0VKXjnarKeJ5rdSuqfORWPRMjHnZ1H7n8X8jeWBk/H4ATvWlq8eNogRo
    67ADg5vfsZFDy+c7kCZD0APBQ8TSdsauS+M2IDnukVSNVVaOLk6/XCi7484vSJOj
    lgRIMVSWF9STJYODrAS+irZ+Q8P8NKghPkK87H9S9QFB7xp/GEVWp0zoRzZn4fbD
    NVDh8TBDF54CIMXCMfm662PhpydDMqJd2lvpVtIpGJ46bPk16CzJPKnTYLfTVS+N
    bUwZsArgyb48Gu806zuevNgnXwIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQASEd0T
    YCJzVQMc4KfjlMA2L7sXB+sBShHO4+NaB2aS99RRjLPy2ng+/ethv9TWWk6JXO4F
    52MYLcMFIHwVnU6hDCFCJZKbjqrTT/dypUqUrgYpjIX3wLP5rW+MfjxJy6PK9Ffn
    MfyZn/bvXD1DHfsJ2heUiPnUE7U6r2CUjFTqdsxcCy8TFrnDzkNSFG97989bNsfv
    wfaN2BxLZD3WkfWgeQYA4FSeu7zyrzyYXEhGDkj4riglM9/tgDMxVdyG9aKOGNgf
    KbkYsCNOswDByy61YcTctdT4wFb6Pc9uCMd4VtF9vguhvkODsoaSSyItUp0vTzaN
    frkHdkDqDEoq7o06
    -----END CERTIFICATE-----
    """

    let clientPrivateKeyData = """
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQD60lzEt7lu42wy
    AvDIXtjfHpxXnK2apIALWE9fMGLxrHr8FPahb5+8HEJVP+yfdOwpRKfRUpeOdqsp
    4nmt1K6p85FY9EyMednUfufxfyN5YGT8fgBO9aWrx42iBGjrsAODm9+xkUPL5zuQ
    JkPQA8FDxNJ2xq5L4zYgOe6RVI1VVo4uTr9cKLvjzi9Ik6OWBEgxVJYX1JMlg4Os
    BL6Ktn5Dw/w0qCE+Qrzsf1L1AUHvGn8YRVanTOhHNmfh9sM1UOHxMEMXngIgxcIx
    +brrY+GnJ0Myol3aW+lW0ikYnjps+TXoLMk8qdNgt9NVL41tTBmwCuDJvjwa7zTr
    O5682CdfAgMBAAECggEBAL+L4R619B3z/g+fYUST8mlKVjkuRQIBOGvxkAPwzs8j
    WnSiicq1lTYyGpJCFDGeODA35zUbLvS0OXjuJOCUuKK/iLN3NfJdp/X4yKcL4gpy
    jAyrKQ8j19Z8ufQODBZZwAVFB6rydeUE/N7T6hu0kmZvrA7bIgaASTiJJWDFQn30
    7em9X3nlM+n/dWl7TvKiLhgUhCVPOrGh4QtI3QPmXLn7DuUID7h3tXpfIm8c2X+K
    wih8pgjSVddcy3ZIFIUTY7UO2AVeOOEWVGHtyFsBrGoYSmOq1/sGQ0kZg5zFgtIN
    xvpjVwU1kbg2RN4LmePrFNlta32/SfCNmVoOBzT4ybkCgYEA/6ACNbbhHh6V6GwK
    olPx0SezbRCcp7fKVB5ue2lfRK1f9Kio8IrEnGRkeP8lqP3R57/6bqa2b9aq9AlB
    84mosLUwL3UQC9B6MdtTf49mj4arNfArPzK30EYGvQ7y0TW7st9A2ngU3mKVg584
    x6DlXRgu/cI4T7LGtYzy36wNDNsCgYEA+zCMzm+LGBwQtyQPOaAkJh3/2QaL5HKF
    /yI+izTskGRkkTNw+CMMYVkulgWYXOfpXfQXSxpPJMkaNSWH11zYgnVFHk8SU5gW
    i2lSxOhUTIwxP2wqpwlTZvxHiJaSTbmWalAyhHXWtzRssCBvZQUthYm5j4GC9/Zh
    /Y/aABuXVM0CgYA25Cw1Tp0Os7CrJTAvZWlC6YyM+gk5tqy63YIJ/DmZ7MTzK5iD
    drj7gE9W8CstG7wMUNw9EI2SfH1fQ/Gmk0PnFjFPr4qPjuf+dsN6W9fBMEDppzYS
    Lxjrn23pASHBLRGuOmSZxTlt+6txhSpTK8i08fF9Skx/SLuE1sx8nVx8CwKBgQC9
    pn1ZS5xgOqhgLgiUwJUqdlH6QNgURmdnJyrDndTSfAn2Gzm7D3NEeLoUqOrNkod+
    2VFQ8e85XeC8qbZzYvVRIktqQ9cZaGX1IjNM2gDzvpFcSkW10fO3eNhlhxG1P18S
    q7RIkFPqBNne7M5OHmetQDvq3qTMpKh9ckPs+uf6LQKBgFyVXuhDw58JzOhBV2FI
    YMbwMSL5yBdh+vGycByn9tv23+6yHf48UUga9G7r5RMqwys3lSX4iMtWhpVyHnut
    hVTQqDbl2Kw1n1N2ctPqeYPVmOnzUjPZyUCL4rRR0xUS6aNBglwXHjfVKI+KzjSJ
    PZlm7jI78/XEnGFY6DLXhk6z
    -----END PRIVATE KEY-----
    """

    func getClientTLSConfiguration() throws -> TLSConfiguration {
        let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
        let certificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData.utf8), format: .pem)
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](clientPrivateKeyData.utf8), format: .pem)
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.trustRoots = .certificates([caCertificate])
        tlsConfig.certificateChain = [.certificate(certificate)]
        tlsConfig.privateKey = .privateKey(privateKey)
        return tlsConfig
    }
}

#endif
