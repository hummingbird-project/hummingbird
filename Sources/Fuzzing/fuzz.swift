import Hummingbird
import HummingbirdCore

@_optimize(none)  // Taken from package-benchmark
public func blackHole(_: some Any) {}

@available(macOS 13, *)
@_cdecl("LLVMFuzzerTestOneInput")
public func test(_ start: UnsafeRawPointer, _ count: Int) -> CInt {
    let bytes = UnsafeRawBufferPointer(start: start, count: count)
    return testRouterPath(bytes)
}

/// Takes random bytes, reduce all bytes to 7 bit ascii, adds random char from "/:{}%"
public func testRouterPath(_ bytes: UnsafeRawBufferPointer) -> CInt {
    var mutatedBytes: [UInt8] = []
    let controlCharacters: [UInt8] = [
        .init(ascii: "/"), .init(ascii: ":"), .init(ascii: "{"), .init(ascii: "}"), .init(ascii: "%"),
    ]
    for byte in bytes {
        mutatedBytes.append(byte & 0x7f)
        let r = Int.random(in: 0..<64)
        if r < controlCharacters.count {
            mutatedBytes.append(controlCharacters[r])
        }
    }
    // TODO: Test the code using the provided bytes.
    let uriString = String(decoding: mutatedBytes, as: UTF8.self)
    let uri = URI(uriString)
    blackHole(RouterPath(uri.path))
    return 0
}
