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

#if !(FUZZ_URL || FUZZ_PERCENTDECODE)
@main
enum LLVMFuzzer {
    static func main() {
        print("You should not run LLVMFuzzer.main")
    }
}

#else

@available(macOS 13, *)
@_cdecl("LLVMFuzzerCustomMutator")
public func mutate(data: UnsafeMutablePointer<UInt8>, size: Int, maxSize: Int, seed: UInt32) -> Int {
    #if FUZZ_URL
    mutateRouterPath(data: data, size: size, maxSize: maxSize, seed: seed)
    #elseif FUZZ_PERCENTDECODE
    mutatePercentDecode(data: data, size: size, maxSize: maxSize, seed: seed)
    #else
    fatalError("Fuzz method not chosen. Use precompiler define.")
    #endif
}

@available(macOS 13, *)
@_cdecl("LLVMFuzzerTestOneInput")
public func test(_ start: UnsafeRawPointer, _ count: Int) -> CInt {
    let bytes = UnsafeRawBufferPointer(start: start, count: count)
    #if FUZZ_URL
    return testRouterPath(bytes)
    #elseif FUZZ_PERCENTDECODE
    return testPercentDecode(bytes)
    #else
    fatalError("Fuzz method not chosen. Use precompiler define.")
    #endif
}

// MARK: URI/RouterPath

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

/// test string converts to URI and then converts to RouterPath
func testRouterPath(_ bytes: UnsafeRawBufferPointer) -> CInt {
    let uriString = String(decoding: bytes, as: UTF8.self)
    let uri = URI(uriString)
    blackHole(RouterPath(uri.path))
    return 0
}

// MARK: Percent decode

/// Mutate so it is ascii 7 bit
func mutatePercentDecode(data: UnsafeMutablePointer<UInt8>, size: Int, maxSize: Int, seed: UInt32) -> Int {
    let newSize = LLVMFuzzerMutate(data, size, maxSize)
    for index in 0..<newSize {
        data[index] = data[index] & 0x7f
    }
    return newSize
}

func testPercentDecode(_ bytes: UnsafeRawBufferPointer) -> CInt {
    let string = String(decoding: bytes, as: UTF8.self)
    blackHole(string.removingURLPercentEncoding())
    return 0
}

#endif
