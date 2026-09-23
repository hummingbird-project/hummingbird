import Foundation
import Hummingbird
import HummingbirdCore
import LLVMFuzzer

// To run fuzzer use
// swift run --sanitize=fuzzer Fuzzing <CORPUS DIR>
// See https://llvm.org/docs/LibFuzzer.html for more details

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

#if !(FUZZ_URL || FUZZ_PERCENTDECODE || FUZZ_URLENCODEDFORM)
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
    LLVMFuzzerMutate(data, size, maxSize)
}

@available(macOS 13, *)
@_cdecl("LLVMFuzzerTestOneInput")
public func test(_ start: UnsafeRawPointer, _ count: Int) -> CInt {
    let bytes = UnsafeRawBufferPointer(start: start, count: count)
    #if FUZZ_URL
    return testRouterPath(bytes)
    #elseif FUZZ_PERCENTDECODE
    return testPercentDecode(bytes)
    #elseif FUZZ_URLENCODEDFORM
    return testURLEncodedFormDecode(bytes)
    #else
    fatalError("Fuzz method not chosen. Use precompiler define.")
    #endif
}

// MARK: URI/RouterPath

/// test string converts to URI and then converts to RouterPath
func testRouterPath(_ bytes: UnsafeRawBufferPointer) -> CInt {
    let uriString = String(decoding: bytes, as: UTF8.self)
    let uri = URI(uriString)
    blackHole(RouterPath(uri.path))
    return 0
}

// MARK: Percent decode

func testPercentDecode(_ bytes: UnsafeRawBufferPointer) -> CInt {
    let string = String(decoding: bytes, as: UTF8.self)
    blackHole(string.removingURLPercentEncoding())
    return 0
}

// MARK: URLEncodedForm

func testURLEncodedFormDecode(_ bytes: UnsafeRawBufferPointer) -> CInt {
    struct TestType: Decodable {
    }
    let string = String(decoding: bytes, as: UTF8.self)
    let result = try? URLEncodedFormDecoder().decode(TestType.self, from: string)
    blackHole(result)
    return 0
}

#endif
