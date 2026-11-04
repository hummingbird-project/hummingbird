//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - Encoding Extensions

extension StringProtocol {

    fileprivate static func hexToAscii(_ hex: UInt8) -> UInt8 {
        switch hex {
        case 0x0:
            return UInt8(ascii: "0")
        case 0x1:
            return UInt8(ascii: "1")
        case 0x2:
            return UInt8(ascii: "2")
        case 0x3:
            return UInt8(ascii: "3")
        case 0x4:
            return UInt8(ascii: "4")
        case 0x5:
            return UInt8(ascii: "5")
        case 0x6:
            return UInt8(ascii: "6")
        case 0x7:
            return UInt8(ascii: "7")
        case 0x8:
            return UInt8(ascii: "8")
        case 0x9:
            return UInt8(ascii: "9")
        case 0xA:
            return UInt8(ascii: "A")
        case 0xB:
            return UInt8(ascii: "B")
        case 0xC:
            return UInt8(ascii: "C")
        case 0xD:
            return UInt8(ascii: "D")
        case 0xE:
            return UInt8(ascii: "E")
        case 0xF:
            return UInt8(ascii: "F")
        default:
            fatalError("Invalid hex digit: \(hex)")
        }
    }

    package func addingPercentEncoding(forURLComponent component: URLComponentSet) -> String {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            unsafe Self.addingPercentEncoding(utf8Buffer: $0.span, component: component)
        }
        if let fastResult {
            return fastResult
        } else {
            let bytes = [UInt8](self.utf8)
            return bytes.withUnsafeBufferPointer { buffer in
                unsafe Self.addingPercentEncoding(utf8Buffer: buffer.span, component: component)
            }
        }
    }

    fileprivate static func addingPercentEncoding(utf8Buffer: Span<UInt8>, component: URLComponentSet) -> String {
        let maxLength = utf8Buffer.count * 3
        let percent = UInt8(ascii: "%")
        #if compiler(<6.4)
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength) { buffer in
            var destIndex = 0
            for srcIndex in utf8Buffer.indices {
                let byte = utf8Buffer[srcIndex]
                if byte.isAllowedIn(component) {
                    unsafe buffer[destIndex] = byte
                    destIndex += 1
                } else {
                    unsafe buffer[destIndex] = percent
                    unsafe buffer[destIndex + 1] = hexToAscii(byte >> 4)
                    unsafe buffer[destIndex + 2] = hexToAscii(byte & 0xF)
                    destIndex += 3
                }
            }
            return unsafe String(decoding: buffer[..<destIndex], as: UTF8.self)
        }
        #else
        return withTemporaryAllocation(of: UInt8.self, capacity: maxLength) { buffer in
            for index in utf8Buffer.indices {
                let byte = utf8Buffer[index]
                if byte.isAllowedIn(component) {
                    buffer.append(byte)
                } else {
                    buffer.append(percent)
                    buffer.append(hexToAscii(byte >> 4))
                    buffer.append(hexToAscii(byte & 0xF))
                }
            }
            return unsafe buffer.withUnsafeBytes { bytes in
                unsafe String(decoding: bytes, as: UTF8.self)
            }
        }
        #endif
    }

    fileprivate static func asciiToHex(_ ascii: UInt8) -> UInt8? {
        switch ascii {
        case UInt8(ascii: "0"):
            return 0x0
        case UInt8(ascii: "1"):
            return 0x1
        case UInt8(ascii: "2"):
            return 0x2
        case UInt8(ascii: "3"):
            return 0x3
        case UInt8(ascii: "4"):
            return 0x4
        case UInt8(ascii: "5"):
            return 0x5
        case UInt8(ascii: "6"):
            return 0x6
        case UInt8(ascii: "7"):
            return 0x7
        case UInt8(ascii: "8"):
            return 0x8
        case UInt8(ascii: "9"):
            return 0x9
        case UInt8(ascii: "A"), UInt8(ascii: "a"):
            return 0xA
        case UInt8(ascii: "B"), UInt8(ascii: "b"):
            return 0xB
        case UInt8(ascii: "C"), UInt8(ascii: "c"):
            return 0xC
        case UInt8(ascii: "D"), UInt8(ascii: "d"):
            return 0xD
        case UInt8(ascii: "E"), UInt8(ascii: "e"):
            return 0xE
        case UInt8(ascii: "F"), UInt8(ascii: "f"):
            return 0xF
        default:
            return nil
        }
    }

    package func removingURLPercentEncoding() -> String? {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            unsafe Self.removingURLPercentEncoding(utf8Buffer: $0.span)
        }
        if let fastResult {
            return fastResult
        } else {
            let bytes = [UInt8](self.utf8)
            return bytes.withUnsafeBufferPointer { buffer in
                unsafe Self.removingURLPercentEncoding(utf8Buffer: buffer.span)
            }
        }
    }

    package static func removingURLPercentEncoding(utf8Buffer: Span<UInt8>) -> String? {
        #if compiler(<6.4)
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: utf8Buffer.count) { buffer -> String? in
            let percent = UInt8(ascii: "%")
            var srcIndex = utf8Buffer.indices.startIndex
            let srcEndIndex = utf8Buffer.indices.endIndex
            var destIndex = 0
            while srcIndex < srcEndIndex {
                let v = utf8Buffer[srcIndex]
                srcIndex += 1
                if v == percent {
                    var hexDigitsRequired = 2
                    var byte: UInt8 = 0
                    while srcIndex < srcEndIndex {
                        let v = utf8Buffer[srcIndex]
                        srcIndex += 1
                        guard let hex = asciiToHex(v) else {
                            return nil
                        }
                        if hexDigitsRequired == 2 {
                            byte = hex << 4
                            hexDigitsRequired -= 1
                        } else if hexDigitsRequired == 1 {
                            byte += hex
                            unsafe buffer[destIndex] = byte
                            destIndex += 1
                            hexDigitsRequired -= 1
                            break
                        }
                    }
                    guard hexDigitsRequired == 0 else {
                        return nil
                    }
                } else {
                    unsafe buffer[destIndex] = v
                    destIndex += 1
                }
            }
            return unsafe String(decoding: buffer[..<destIndex], as: UTF8.self)
        }
        #else
        return withTemporaryAllocation(of: UInt8.self, capacity: utf8Buffer.count) { buffer -> String? in
            let percent = UInt8(ascii: "%")
            var index = utf8Buffer.indices.startIndex
            let endIndex = utf8Buffer.indices.endIndex
            while index < endIndex {
                let v = utf8Buffer[index]
                index += 1
                if v == percent {
                    var hexDigitsRequired = 2
                    var byte: UInt8 = 0
                    while index < endIndex {
                        let v = utf8Buffer[index]
                        index += 1
                        guard let hex = asciiToHex(v) else {
                            return nil
                        }
                        if hexDigitsRequired == 2 {
                            byte = hex << 4
                            hexDigitsRequired -= 1
                        } else if hexDigitsRequired == 1 {
                            byte += hex
                            buffer.append(byte)
                            hexDigitsRequired -= 1
                            break
                        }
                    }
                    guard hexDigitsRequired == 0 else {
                        return nil
                    }
                } else {
                    buffer.append(v)
                }
            }
            return unsafe buffer.withUnsafeBytes { bytes in
                unsafe String(decoding: bytes, as: UTF8.self)
            }
        }
        #endif
    }
}

// MARK: - Validation Extensions

package struct URLComponentSet: OptionSet {
    package let rawValue: UInt8
    package init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    package static let scheme = URLComponentSet(rawValue: 1 << 0)

    // user, password, and hostIPLiteral use the same allowed character set.
    package static let user = URLComponentSet(rawValue: 1 << 1)
    package static let password = URLComponentSet(rawValue: 1 << 1)
    package static let hostIPLiteral = URLComponentSet(rawValue: 1 << 1)

    package static let host = URLComponentSet(rawValue: 1 << 2)
    package static let hostZoneID = URLComponentSet(rawValue: 1 << 3)
    package static let path = URLComponentSet(rawValue: 1 << 4)
    package static let pathFirstSegment = URLComponentSet(rawValue: 1 << 5)

    // query and fragment use the same allowed character set.
    package static let query = URLComponentSet(rawValue: 1 << 6)
    package static let fragment = URLComponentSet(rawValue: 1 << 6)

    package static let queryItem = URLComponentSet(rawValue: 1 << 7)
}

extension UTF8.CodeUnit {
    fileprivate func isAllowedIn(_ component: URLComponentSet) -> Bool {
        allowedURLComponents & component.rawValue != 0
    }

    // ===------------------------------------------------------------------------------------=== //
    // allowedURLComponents was written programmatically using the following grammar from RFC 3986:
    //
    // let ALPHA       = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    // let DIGIT       = "0123456789"
    // let HEXDIG      = DIGIT + "ABCDEFabcdef"
    // let gen_delims  = ":/?#[]@"
    // let sub_delims  = "!$&'()*+,;="
    // let unreserved  = ALPHA + DIGIT + "-._~"
    // let reserved    = gen_delims + sub_delims
    // NOTE: "%" is allowed in pchar and reg_name, but we must validate that 2 HEXDIG follow it
    // let pchar       = unreserved + sub_delims + ":" + "@"
    // let reg_name    = unreserved + sub_delims
    //
    // let schemeAllowed            = CharacterSet(charactersIn: ALPHA + DIGIT + "+-.")
    // let userinfoAllowed          = CharacterSet(charactersIn: unreserved + sub_delims + ":")
    // let hostAllowed              = CharacterSet(charactersIn: reg_name)
    // let hostIPLiteralAllowed     = CharacterSet(charactersIn: unreserved + sub_delims + ":")
    // let hostZoneIDAllowed        = CharacterSet(charactersIn: unreserved)
    // let portAllowed              = CharacterSet(charactersIn: DIGIT)
    // let pathAllowed              = CharacterSet(charactersIn: pchar + "/")
    // let pathFirstSegmentAllowed  = pathAllowed.subtracting(CharacterSet(charactersIn: ":"))
    // let queryAllowed             = CharacterSet(charactersIn: pchar + "/?")
    // let queryItemAllowed         = queryAllowed.subtracting(CharacterSet(charactersIn: "=&"))
    // let fragmentAllowed          = CharacterSet(charactersIn: pchar + "/?")
    // ===------------------------------------------------------------------------------------=== //
    fileprivate var allowedURLComponents: URLComponentSet.RawValue {
        switch self {
        case UInt8(ascii: "!"):
            return 0b11110110
        case UInt8(ascii: "$"):
            return 0b11110110
        case UInt8(ascii: "&"):
            return 0b01110110
        case UInt8(ascii: "'"):
            return 0b11110110
        case UInt8(ascii: "("):
            return 0b11110110
        case UInt8(ascii: ")"):
            return 0b11110110
        case UInt8(ascii: "*"):
            return 0b11110110
        case UInt8(ascii: "+"):
            return 0b11110111
        case UInt8(ascii: ","):
            return 0b11110110
        case UInt8(ascii: "-"):
            return 0b11111111
        case UInt8(ascii: "."):
            return 0b11111111
        case UInt8(ascii: "/"):
            return 0b11110000
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return 0b11111111
        case UInt8(ascii: ":"):
            return 0b11010010
        case UInt8(ascii: ";"):
            return 0b11110110
        case UInt8(ascii: "="):
            return 0b01110110
        case UInt8(ascii: "?"):
            return 0b11000000
        case UInt8(ascii: "@"):
            return 0b11110000
        case UInt8(ascii: "A")...UInt8(ascii: "Z"):
            return 0b11111111
        case UInt8(ascii: "_"):
            return 0b11111110
        case UInt8(ascii: "a")...UInt8(ascii: "z"):
            return 0b11111111
        case UInt8(ascii: "~"):
            return 0b11111110
        default:
            return 0
        }
    }
}
