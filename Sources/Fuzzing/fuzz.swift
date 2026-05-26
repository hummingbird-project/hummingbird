import Foundation
import Hummingbird
import HummingbirdCore
import LLVMFuzzer

@_optimize(none)  // Taken from package-benchmark
public func blackHole(_: some Any) {}

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) {
        // Set the random seed
        srand48(seed)
    }

    func next() -> UInt64 {
        // drand48() returns a Double, transform to UInt64
        withUnsafeBytes(of: drand48()) { bytes in
            bytes.load(as: UInt64.self)
        }
    }
}

@available(macOS 13, *)
@_cdecl("LLVMFuzzerCustomMutator")
public func mutate(data: UnsafeMutablePointer<UInt8>, size: Int, maxSize: Int, seed: UInt32) -> Int {
    mutateRouterPath(data: data, size: size, maxSize: maxSize, seed: seed)
}

@available(macOS 13, *)
@_cdecl("LLVMFuzzerTestOneInput")
public func test(_ start: UnsafeRawPointer, _ count: Int) -> CInt {
    let bytes = UnsafeRawBufferPointer(start: start, count: count)
    return testRouterPath(bytes)
}

/// Mutate random data so always starts with a "/" and everything is ascii 7 bit
func mutateRouterPath(data: UnsafeMutablePointer<UInt8>, size: Int, maxSize: Int, seed: UInt32) -> Int {
    let newSize = LLVMFuzzerMutate(data, size, maxSize)
    guard newSize > 1 else {
        data[0] = data[0] & 0x7f
        return newSize
    }
    data[0] = UInt8(ascii: "/")
    var rng = RandomNumberGeneratorWithSeed(seed: Int(bitPattern: UInt(seed)))

    let controlCharacters: [UInt8] = [
        .init(ascii: "/"), .init(ascii: ":"), .init(ascii: "{"), .init(ascii: "}"), .init(ascii: "%"), .init(ascii: "?"), .init(ascii: "="),
        .init(ascii: "&"),
    ]
    for index in 1..<newSize {
        let r = Int.random(in: 0..<128, using: &rng)
        if r < controlCharacters.count {
            data[index] = controlCharacters[r]
        } else {
            data[index] = data[index] & 0x7f
        }
    }
    return newSize
}

/// Takes random bytes, reduce all bytes to 7 bit ascii, adds random char from "/:{}%"
func testRouterPath(_ bytes: UnsafeRawBufferPointer) -> CInt {
    let uriString = String(decoding: bytes, as: UTF8.self)
    let uri = URI(uriString)
    blackHole(RouterPath(uri.path))
    return 0
}
