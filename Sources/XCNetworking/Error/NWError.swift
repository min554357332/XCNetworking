//
//  NWError.swift
//  
//
//  Created by 大江山岚 on 2023/7/5.
//

import Foundation

public struct NWError: NWErrorProtocol, DebuggableError {
    /// Creates a redirecting `NWError` error.
    ///
    ///     throw NWError.redirect(to: "https://vapor.codes")"
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    /// - Parameters:
    ///   - location: The path to redirect to
    ///   - type: The type of redirect to perform
    /// - Returns: An abort error that provides a redirect to the specified location
    @available(*, deprecated, renamed: "redirect(to:redirectType:)")
    public static func redirect(to location: String, type: RedirectType) -> NWError {
        var headers: NWHeaders = [:]
        headers.replaceOrAdd(name: .location, value: location)
        return .init(type.status, headers: headers)
    }
    
    /// Creates a redirecting `Abort` error.
    ///
    ///     throw Abort.redirect(to: "https://vapor.codes")
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    /// - Parameters:
    ///   - location: The path to redirect to
    ///   - redirectType: The type of redirect to perform
    /// - Returns: An abort error that provides a redirect to the specified location
    public static func redirect(to location: String, redirectType: Redirect = .normal) -> NWError {
        var headers: NWHeaders = [:]
        headers.replaceOrAdd(name: .location, value: location)
        return .init(redirectType.status, headers: headers)
    }

    /// See `Debuggable`
    public var identifier: String

    /// See `AbortError`
    public var status: NWResponseStatus

    /// See `AbortError`.
    public var headers: NWHeaders

    /// See `AbortError`
    public var reason: String

    /// Source location where this error was created.
    public var source: ErrorSource?

    /// Stack trace at point of error creation.
    public var stackTrace: StackTrace?

    /// Create a new `Abort`, capturing current source location info.
    public init(
        _ status: NWResponseStatus,
        headers: NWHeaders = [:],
        reason: String? = nil,
        identifier: String? = nil,
        suggestedFixes: [String] = [],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column,
        range: Range<UInt>? = nil,
        stackTrace: StackTrace? = .capture(skip: 1)
    ) {
        self.identifier = identifier ?? status.code.description
        self.headers = headers
        self.status = status
        self.reason = reason ?? status.reasonPhrase
        self.source = ErrorSource(
            file: file,
            function: function,
            line: line,
            column: column,
            range: range
        )
        self.stackTrace = stackTrace
    }
}

@available(*, deprecated, renamed: "Redirect")
public enum RedirectType {
    /// A cacheable redirect. Not all user-agents preserve request method and body, so
    /// this should only be used for GET or HEAD requests
    /// `301 permanent`
    case permanent
    /// Forces the redirect to come with a GET, regardless of req method.
    /// `303 see other`
    case normal
    /// Maintains original request method, ie: PUT will call PUT on redirect.
    /// `307 Temporary`
    case temporary

    /// Associated `HTTPStatus` for this redirect type.
    public var status: NWResponseStatus {
        switch self {
        case .permanent: return .movedPermanently
        case .normal: return .seeOther
        case .temporary: return .temporaryRedirect
        }
    }
}

public struct Redirect {
    let kind: Kind
    
    /// A cacheable redirect. Not all user-agents preserve request method and body, so
    /// this should only be used for GET or HEAD requests
    /// `301 permanent`
    public static var permanent: Redirect {
        return Self(kind: .permanent)
    }
    
    /// Forces the redirect to come with a GET, regardless of req method.
    /// `303 see other`
    public static var normal: Redirect {
        return Self(kind: .normal)
    }
    
    /// Maintains original request method, ie: PUT will call PUT on redirect.
    /// `307 Temporary`
    public static var temporary: Redirect {
        return Self(kind: .temporary)
    }
    
    /// Redirect where the request method and the body will not be altered. This should
    /// be used for POST redirects.
    /// `308 Permanent Redirect`
    public static var permanentPost: Redirect {
        return Self(kind: .permanentPost)
    }

    /// Associated `HTTPStatus` for this redirect type.
    public var status: NWResponseStatus {
        switch self.kind {
        case .permanent: return .movedPermanently
        case .normal: return .seeOther
        case .temporary: return .temporaryRedirect
        case .permanentPost: return .permanentRedirect
        }
    }
    
    enum Kind {
        case permanent
        case normal
        case temporary
        case permanentPost
    }
}


public protocol NWErrorProtocol: Error {
    var reason: String { get }
    var status: NWResponseStatus { get }
    var headers: NWHeaders { get }
}

extension NWErrorProtocol {
    public var headers: NWHeaders {
        [:]
    }
    public var reason: String {
        self.status.reasonPhrase
    }
}

extension NWErrorProtocol where Self: DebuggableError {
    public var identifier: String {
        self.status.code.description
    }
}

extension Array where Element == CodingKey {
    public var dotPath: String { self.map(\.stringValue).joined(separator: ".") }
}

extension DecodingError: NWErrorProtocol {
    /// See `AbortError.status`
    public var status: NWResponseStatus {
        return .badRequest
    }

    /// See `AbortError.identifier`
    public var identifier: String {
        switch self {
        case .dataCorrupted: return "dataCorrupted"
        case .keyNotFound: return "keyNotFound"
        case .typeMismatch: return "typeMismatch"
        case .valueNotFound: return "valueNotFound"
        @unknown default: return "unknown"
        }
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        return "Decoding error: \(self.reason)"
    }

    /// See `AbortError.reason`
    public var reason: String {
        switch self {
        case .dataCorrupted(let ctx):
            return "Data corrupted at path '\(ctx.codingPath.dotPath)'\(ctx.debugDescriptionAndUnderlyingError)"
        case .keyNotFound(let key, let ctx):
            let path = ctx.codingPath + [key]
            return "Value required for key at path '\(path.dotPath)'\(ctx.debugDescriptionAndUnderlyingError)"
        case .typeMismatch(let type, let ctx):
            return "Value at path '\(ctx.codingPath.dotPath)' was not of type '\(type)'\(ctx.debugDescriptionAndUnderlyingError)"
        case .valueNotFound(let type, let ctx):
            return "Value of type '\(type)' was not found at path '\(ctx.codingPath.dotPath)'\(ctx.debugDescriptionAndUnderlyingError)"
        @unknown default: return "Unknown error."
        }
    }
}

private extension DecodingError.Context {
    var debugDescriptionAndUnderlyingError: String {
        "\(self.debugDescriptionNoTrailingDot)\(self.underlyingErrorDescription)."
    }
    
    /// `debugDescription` sometimes has a trailing dot, and sometimes not.
    private var debugDescriptionNoTrailingDot: String {
        if self.debugDescription.isEmpty {
            return ""
        } else if self.debugDescription.last == "." {
            return ". \(String(self.debugDescription.dropLast()))"
        } else {
            return ". \(self.debugDescription)"
        }
    }
    
    private var underlyingErrorDescription: String {
        if let underlyingError = self.underlyingError {
            return ". Underlying error: \(underlyingError)"
        } else {
            return ""
        }
    }
}
