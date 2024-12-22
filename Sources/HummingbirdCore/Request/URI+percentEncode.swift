//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// MARK: - Encoding Extensions

extension StringProtocol {

    fileprivate func hexToAscii(_ hex: UInt8) -> UInt8 {
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

    fileprivate func addingPercentEncoding(forURLComponent component: URLComponentSet) -> String {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            addingPercentEncoding(utf8Buffer: $0, component: component)
        }
        if let fastResult {
            return fastResult
        } else {
            return addingPercentEncoding(utf8Buffer: utf8, component: component)
        }
    }

    fileprivate func addingPercentEncoding(utf8Buffer: some Collection<UInt8>, component: URLComponentSet) -> String {
        let maxLength = utf8Buffer.count * 3
        let result = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength + 1) { _buffer in
            var buffer = OutputBuffer(initializing: _buffer.baseAddress!, capacity: _buffer.count)
            for v in utf8Buffer {
                if v.isAllowedIn(component) {
                    buffer.appendElement(v)
                } else {
                    buffer.appendElement(UInt8(ascii: "%"))
                    buffer.appendElement(hexToAscii(v >> 4))
                    buffer.appendElement(hexToAscii(v & 0xF))
                }
            }
            buffer.appendElement(0)  // NULL-terminated
            let initialized = buffer.relinquishBorrowedMemory()
            return String(cString: initialized.baseAddress!)
        }
        return result
    }

    fileprivate func asciiToHex(_ ascii: UInt8) -> UInt8? {
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

    fileprivate func removingURLPercentEncoding(excluding: Set<UInt8> = []) -> String? {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            removingURLPercentEncoding(utf8Buffer: $0, excluding: excluding)
        }
        if let fastResult {
            return fastResult
        } else {
            return removingURLPercentEncoding(utf8Buffer: utf8, excluding: excluding)
        }
    }

    fileprivate func removingURLPercentEncoding(utf8Buffer: some Collection<UInt8>, excluding: Set<UInt8>) -> String? {
        let result: String? = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: utf8Buffer.count) { buffer -> String? in
            var i = 0
            var byte: UInt8 = 0
            var hexDigitsRequired = 0
            for v in utf8Buffer {
                if v == UInt8(ascii: "%") {
                    guard hexDigitsRequired == 0 else {
                        return nil
                    }
                    hexDigitsRequired = 2
                } else if hexDigitsRequired > 0 {
                    guard let hex = asciiToHex(v) else {
                        return nil
                    }
                    if hexDigitsRequired == 2 {
                        byte = hex << 4
                    } else if hexDigitsRequired == 1 {
                        byte += hex
                        if excluding.contains(byte) {
                            // Keep the original percent-encoding for this byte
                            i = buffer[i...i + 2].initialize(fromContentsOf: [UInt8(ascii: "%"), hexToAscii(byte >> 4), v])
                        } else {
                            buffer[i] = byte
                            i += 1
                            byte = 0
                        }
                    }
                    hexDigitsRequired -= 1
                } else {
                    buffer[i] = v
                    i += 1
                }
            }
            guard hexDigitsRequired == 0 else {
                return nil
            }
            return String(decoding: buffer[..<i], as: UTF8.self)
        }
        return result
    }
}

// MARK: - Validation Extensions

private struct URLComponentSet: OptionSet {
    let rawValue: UInt8
    static let scheme = URLComponentSet(rawValue: 1 << 0)

    // user, password, and hostIPLiteral use the same allowed character set.
    static let user = URLComponentSet(rawValue: 1 << 1)
    static let password = URLComponentSet(rawValue: 1 << 1)
    static let hostIPLiteral = URLComponentSet(rawValue: 1 << 1)

    static let host = URLComponentSet(rawValue: 1 << 2)
    static let hostZoneID = URLComponentSet(rawValue: 1 << 3)
    static let path = URLComponentSet(rawValue: 1 << 4)
    static let pathFirstSegment = URLComponentSet(rawValue: 1 << 5)

    // query and fragment use the same allowed character set.
    static let query = URLComponentSet(rawValue: 1 << 6)
    static let fragment = URLComponentSet(rawValue: 1 << 6)

    static let queryItem = URLComponentSet(rawValue: 1 << 7)
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
