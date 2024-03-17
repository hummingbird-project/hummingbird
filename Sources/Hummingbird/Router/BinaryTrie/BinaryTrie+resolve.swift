import NIOCore

extension BinaryTrie {
    /// Resolve a path to a `Value` if available
    func resolve(_ path: String) -> (value: Value, parameters: Parameters)? {
        var trie = trie
        var pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var parameters = Parameters()

        if pathComponents.isEmpty {
            return value(for: 0, parameters: parameters)
        }

        return descendPath(
            in: &trie,
            index: 0,
            parameters: &parameters,
            components: &pathComponents
        )
    }

    /// If `index != nil`, resolves the `index` to a `Value`
    /// This is used as a helper in `descendPath(in:parameters:components:)`
    private func value(for index: UInt16?, parameters: Parameters) -> (value: Value, parameters: Parameters)? {
        if let index, let value = self.values[Int(index)] {
            return (value: value, parameters: parameters)
        }

        return nil
    }

    /// A function that takes a path component and descends the trie to find the value
    private func descendPath(
        in trie: inout ByteBuffer,
        index: UInt16,
        parameters: inout Parameters,
        components: inout [Substring]
    ) -> (value: Value, parameters: Parameters)? {
        // If there are no more components in the path, return the value found
        if components.isEmpty {
            return value(for: index, parameters: parameters)
        }

        // Take the next component from the path
        var component = components.removeFirst()
        
        // Check the current node type through TokenKind
        // And read the location of the _next_ node from the trie buffer
        while 
            let index = trie.readInteger(as: UInt16.self),
            let _token: Integer = trie.readInteger(),
            let token = TokenKind(rawValue: _token),
            let nextNodeIndex: UInt32 = trie.readInteger()
        {
            switch token {
            case .path:
                // The current node is a constant
                guard
                    let length: Integer = trie.readInteger(),
                    trie.readAndCompareString(to: &component, length: length)
                else {
                    // The constant's does not match the component's length
                    // So we can skip to the next sibling
                    trie.moveReaderIndex(to: Int(nextNodeIndex))
                    continue
                }
            case .capture:
                // The current node is a parameter
                guard
                    let length: Integer = trie.readInteger(),
                    let parameter = trie.readString(length: Int(length))
                else {
                    // The constant's does not match the component's length
                    // So we can skip to the next sibling
                    trie.moveReaderIndex(to: Int(nextNodeIndex))
                    return nil
                }

                parameters[Substring(parameter)] = component
            case .prefixCapture:
                guard
                    let suffixLength: Integer = trie.readInteger(),
                    let suffix = trie.readString(length: Int(suffixLength)),
                    let parameterLength: Integer = trie.readInteger(),
                    let parameter = trie.readString(length: Int(parameterLength)),
                    component.hasSuffix(suffix)
                else {
                    // The constant's does not match the component's length
                    // So we can skip to the next sibling
                    trie.moveReaderIndex(to: Int(nextNodeIndex))
                    continue
                }

                component.removeLast(suffix.count)
                parameters[Substring(parameter)] = component
            case .suffixCapture:
                guard
                    let prefixLength: Integer = trie.readInteger(),
                    trie.readAndCompareString(to: &component, length: prefixLength),
                    let parameterLength: Integer = trie.readInteger(),
                    let parameter = trie.readString(length: Int(parameterLength))
                else {
                    // The constant's does not match the component's length
                    // So we can skip to the next sibling
                    trie.moveReaderIndex(to: Int(nextNodeIndex))
                    continue
                }

                component.removeFirst(Int(prefixLength))
                parameters[Substring(parameter)] = component
            case .wildcard:
                // Always matches, descend
                ()
            case .prefixWildcard:
                guard
                    let suffixLength: Integer = trie.readInteger(),
                    let suffix = trie.readString(length: Int(suffixLength)),
                    component.hasSuffix(suffix)
                else {
                    // The constant's does not match the component's length
                    // So we can skip to the next sibling
                    trie.moveReaderIndex(to: Int(nextNodeIndex))
                    continue
                }
            case .suffixWildcard:
                guard
                    let prefixLength: Integer = trie.readInteger(),
                    trie.readAndCompareString(to: &component, length: prefixLength)
                else {
                    // The constant's does not match the component's length
                    // So we can skip to the next sibling
                    trie.moveReaderIndex(to: Int(nextNodeIndex))
                    continue
                }
            case .recursiveWildcard:
                fatalError()
            case .null:
                continue
            case .deadEnd:
                return nil
            }

            // This node matches!
            return descendPath(
                in: &trie,
                index: index,
                parameters: &parameters,
                components: &components
            )
        }

        return nil
    }
}

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Musl)
import Musl
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
#error("unsupported os")
#endif

fileprivate extension ByteBuffer {
    mutating func readAndCompareString<Length: FixedWidthInteger>(to string: inout Substring, length: Length) -> Bool {
        let length = Int(length)
        return string.withUTF8 { utf8 in
            if utf8.count != length {
                return false
            }

            return withUnsafeReadableBytes { buffer in
                if memcmp(utf8.baseAddress, buffer.baseAddress, length) == 0 {
                    moveReaderIndex(forwardBy: length)
                    return true
                } else {
                    return false
                }
            }
        }
    }
}
