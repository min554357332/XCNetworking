//
//  NWHeaders.swift
//  
//
//  Created by 大江山岚 on 2023/7/5.
//

import Foundation

internal enum KeepAliveState {
    // We know keep alive should be used.
    case keepAlive
    // We know we should close the connection.
    case close
    // We need to scan the headers to find out if keep alive is used or not
    case unknown
}

extension Sequence where Self.Element == UInt8 {
    /// Compares the collection of `UInt8`s to a case insensitive collection.
    ///
    /// This collection could be get from applying the `UTF8View`
    ///   property on the string protocol.
    ///
    /// - Parameter bytes: The string constant in the form of a collection of `UInt8`
    /// - Returns: Whether the collection contains **EXACTLY** this array or no, but by ignoring case.
    internal func compareCaseInsensitiveASCIIBytes<T: Sequence>(to: T) -> Bool
        where T.Element == UInt8 {
            // fast path: we can get the underlying bytes of both
            let maybeMaybeResult = self.withContiguousStorageIfAvailable { lhsBuffer -> Bool? in
                to.withContiguousStorageIfAvailable { rhsBuffer in
                    if lhsBuffer.count != rhsBuffer.count {
                        return false
                    }

                    for idx in 0 ..< lhsBuffer.count {
                        // let's hope this gets vectorised ;)
                        if lhsBuffer[idx] & 0xdf != rhsBuffer[idx] & 0xdf {
                            return false
                        }
                    }
                    return true
                }
            }

            if let maybeResult = maybeMaybeResult, let result = maybeResult {
                return result
            } else {
                return self.elementsEqual(to, by: {return ($0 & 0xdf) == ($1 & 0xdf)})
            }
    }
}

private extension UInt8 {
    var isASCII: Bool {
        return self <= 127
    }
}

extension UTF8.CodeUnit {
    var isASCIIWhitespace: Bool {
        switch self {
        case UInt8(ascii: " "),
             UInt8(ascii: "\t"):
          return true

        default:
          return false
        }
    }
}

extension String {
    internal func isEqualCaseInsensitiveASCIIBytes(to: String) -> Bool {
        return self.utf8.compareCaseInsensitiveASCIIBytes(to: to.utf8)
    }
}

extension Substring {
    fileprivate func trimWhitespace() -> Substring {
        guard let firstNonWhitespace = self.utf8.firstIndex(where: { !$0.isASCIIWhitespace }) else {
          // The whole substring is ASCII whitespace.
          return Substring()
        }

        // There must be at least one non-ascii whitespace character, so banging here is safe.
        let lastNonWhitespace = self.utf8.lastIndex(where: { !$0.isASCIIWhitespace })!
        return Substring(self.utf8[firstNonWhitespace...lastNonWhitespace])
    }
}

public struct NWHeaders: CustomStringConvertible, ExpressibleByDictionaryLiteral {
    @usableFromInline
    internal var headers: [(String, String)]
    internal var keepAliveState: KeepAliveState = .unknown

    public var description: String {
        return self.headers.description
    }

    internal var names: [String] {
        return self.headers.map { $0.0 }
    }

    internal init(_ headers: [(String, String)], keepAliveState: KeepAliveState) {
        self.headers = headers
        self.keepAliveState = keepAliveState
    }

    internal func isConnectionHeader(_ name: String) -> Bool {
        return name.utf8.compareCaseInsensitiveASCIIBytes(to: "connection".utf8)
    }

    /// Construct a `HTTPHeaders` structure.
    ///
    /// - parameters
    ///     - headers: An initial set of headers to use to populate the header block.
    ///     - allocator: The allocator to use to allocate the underlying storage.
    public init(_ headers: [(String, String)] = []) {
        // Note: this initializer exists because of https://bugs.swift.org/browse/SR-7415.
        // Otherwise we'd only have the one below with a default argument for `allocator`.
        self.init(headers, keepAliveState: .unknown)
    }

    /// Construct a `HTTPHeaders` structure.
    ///
    /// - parameters
    ///     - elements: name, value pairs provided by a dictionary literal.
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(elements)
    }

    /// Add a header name/value pair to the block.
    ///
    /// This method is strictly additive: if there are other values for the given header name
    /// already in the block, this will add a new entry.
    ///
    /// - Parameter name: The header field name. For maximum compatibility this should be an
    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
    ///     recommended.
    /// - Parameter value: The header field value to add for the given name.
    public mutating func add(name: String, value: String) {
        precondition(!name.utf8.contains(where: { !$0.isASCII }), "name must be ASCII")
        self.headers.append((name, value))
        if self.isConnectionHeader(name) {
            self.keepAliveState = .unknown
        }
    }

    /// Add a sequence of header name/value pairs to the block.
    ///
    /// This method is strictly additive: if there are other entries with the same header
    /// name already in the block, this will add new entries.
    ///
    /// - Parameter contentsOf: The sequence of header name/value pairs. For maximum compatibility
    ///     the header should be an ASCII string. For future-proofing with HTTP/2 lowercase header
    ///     names are strongly recommended.
    @inlinable
    public mutating func add<S: Sequence>(contentsOf other: S) where S.Element == (String, String) {
        self.headers.reserveCapacity(self.headers.count + other.underestimatedCount)
        for (name, value) in other {
            self.add(name: name, value: value)
        }
    }

    /// Add another block of headers to the block.
    ///
    /// - Parameter contentsOf: The block of headers to add to these headers.
    public mutating func add(contentsOf other: NWHeaders) {
        self.headers.append(contentsOf: other.headers)
        if other.keepAliveState == .unknown {
            self.keepAliveState = .unknown
        }
    }

    /// Add a header name/value pair to the block, replacing any previous values for the
    /// same header name that are already in the block.
    ///
    /// This is a supplemental method to `add` that essentially combines `remove` and `add`
    /// in a single function. It can be used to ensure that a header block is in a
    /// well-defined form without having to check whether the value was previously there.
    /// Like `add`, this method performs case-insensitive comparisons of the header field
    /// names.
    ///
    /// - Parameter name: The header field name. For maximum compatibility this should be an
    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
    //      recommended.
    /// - Parameter value: The header field value to add for the given name.
    public mutating func replaceOrAdd(name: String, value: String) {
        if self.isConnectionHeader(name) {
            self.keepAliveState = .unknown
        }
        self.remove(name: name)
        self.add(name: name, value: value)
    }

    /// Remove all values for a given header name from the block.
    ///
    /// This method uses case-insensitive comparisons for the header field name.
    ///
    /// - Parameter name: The name of the header field to remove from the block.
    public mutating func remove(name nameToRemove: String) {
        if self.isConnectionHeader(nameToRemove) {
            self.keepAliveState = .unknown
        }
        self.headers.removeAll { (name, _) in
            if nameToRemove.utf8.count != name.utf8.count {
                return false
            }

            return nameToRemove.utf8.compareCaseInsensitiveASCIIBytes(to: name.utf8)
        }
    }

    /// Retrieve all of the values for a give header field name from the block.
    ///
    /// This method uses case-insensitive comparisons for the header field name. It
    /// does not return a maximally-decomposed list of the header fields, but instead
    /// returns them in their original representation: that means that a comma-separated
    /// header field list may contain more than one entry, some of which contain commas
    /// and some do not. If you want a representation of the header fields suitable for
    /// performing computation on, consider `subscript(canonicalForm:)`.
    ///
    /// - Parameter name: The header field name whose values are to be retrieved.
    /// - Returns: A list of the values for that header field name.
    public subscript(name: String) -> [String] {
        return self.headers.reduce(into: []) { target, lr in
            let (key, value) = lr
            if key.utf8.compareCaseInsensitiveASCIIBytes(to: name.utf8) {
                target.append(value)
            }
        }
    }

    /// Retrieves the first value for a given header field name from the block.
    ///
    /// This method uses case-insensitive comparisons for the header field name. It
    /// does not return the first value from a maximally-decomposed list of the header fields,
    /// but instead returns the first value from the original representation: that means
    /// that a comma-separated header field list may contain more than one entry, some of
    /// which contain commas and some do not. If you want a representation of the header fields
    /// suitable for performing computation on, consider `subscript(canonicalForm:)`.
    ///
    /// - Parameter name: The header field name whose first value should be retrieved.
    /// - Returns: The first value for the header field name.
    public func first(name: String) -> String? {
        guard !self.headers.isEmpty else {
            return nil
        }

        return self.headers.first { header in header.0.isEqualCaseInsensitiveASCIIBytes(to: name) }?.1
    }

    /// Checks if a header is present
    ///
    /// - parameters:
    ///     - name: The name of the header
    //  - returns: `true` if a header with the name (and value) exists, `false` otherwise.
    public func contains(name: String) -> Bool {
        for kv in self.headers {
            if kv.0.utf8.compareCaseInsensitiveASCIIBytes(to: name.utf8) {
                return true
            }
        }
        return false
    }

    /// Retrieves the header values for the given header field in "canonical form": that is,
    /// splitting them on commas as extensively as possible such that multiple values received on the
    /// one line are returned as separate entries. Also respects the fact that Set-Cookie should not
    /// be split in this way.
    ///
    /// - Parameter name: The header field name whose values are to be retrieved.
    /// - Returns: A list of the values for that header field name.
    public subscript(canonicalForm name: String) -> [Substring] {
        let result = self[name]

        guard result.count > 0 else {
            return []
        }

        // It's not safe to split Set-Cookie on comma.
        guard name.lowercased() != "set-cookie" else {
            return result.map { $0[...] }
        }

        return result.flatMap { $0.split(separator: ",").map { $0.trimWhitespace() } }
    }
}


extension NWHeaders: Sendable {}

extension NWHeaders {

    /// The total number of headers that can be contained without allocating new storage.
    public var capacity: Int {
        return self.headers.capacity
    }

    /// Reserves enough space to store the specified number of headers.
    ///
    /// - Parameter minimumCapacity: The requested number of headers to store.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        self.headers.reserveCapacity(minimumCapacity)
    }
}

extension NWHeaders: RandomAccessCollection {
    public typealias Element = (name: String, value: String)

    public struct Index: Comparable {
        fileprivate let base: Array<(String, String)>.Index
        public static func < (lhs: Index, rhs: Index) -> Bool {
            return lhs.base < rhs.base
        }
    }

    public var startIndex: NWHeaders.Index {
        return .init(base: self.headers.startIndex)
    }

    public var endIndex: NWHeaders.Index {
        return .init(base: self.headers.endIndex)
    }

    public func index(before i: NWHeaders.Index) -> NWHeaders.Index {
        return .init(base: self.headers.index(before: i.base))
    }

    public func index(after i: NWHeaders.Index) -> NWHeaders.Index {
        return .init(base: self.headers.index(after: i.base))
    }

    public subscript(position: NWHeaders.Index) -> Element {
        return self.headers[position.base]
    }
}

extension NWHeaders: Equatable {
    public static func ==(lhs: NWHeaders, rhs: NWHeaders) -> Bool {
        guard lhs.headers.count == rhs.headers.count else {
            return false
        }
        let lhsNames = Set(lhs.names.map { $0.lowercased() })
        let rhsNames = Set(rhs.names.map { $0.lowercased() })
        guard lhsNames == rhsNames else {
            return false
        }

        for name in lhsNames {
            guard lhs[name].sorted() == rhs[name].sorted() else {
                return false
            }
        }

        return true
    }
}
