//
//  NWRequest.swift
//  networking
//
//  Created by mac on 2024/1/25.
//

import Foundation
import Alamofire
// <T: Decodable>(of type: T.Type,
open class NWRequest<T: Json> {
    
    public init() {}
    
    public typealias ProgressHandler = (Progress) -> Void
    
    open func scheme() -> String {
        #if DEBUG
        return "http"
        #else
        return "https"
        #endif
    }
    
    open func host() -> String {
        fatalError("必须重写host方法")
    }
    
    open func path() -> String {
        fatalError("必须重写path方法")
    }
    
    open func timeout() -> TimeInterval {
        return 15
    }
    
    open func method() -> NWMethod {
        return .GET
    }
    
    open func addHeader(_ key: String, val: String) {
        if self.header == nil {
            self.header = [:]
        }
        self.header?[key] = val
    }
    
    open func addQuery(_ key: String, val: String?) {
        if self.query == nil {
            self.query = [:]
        }
        self.query?[key] = val
    }
    
    open func addBody(_ key: String, val: Any) {
        if self.body == nil {
            self.body = [:]
        }
        self.body?[key] = val
    }
    
    open func addFromData(_ key: String, val: Any) {
        if self.fromData == nil {
            self.fromData = [:]
        }
        self.fromData?[key] = val
    }
    
    open func interceptors() -> NWInterceptor? {
        return nil
    }
    
    public var header: [String: String]?
    public var query: [String: String?]?
    public var body: [String: Any]?
    public var fromData: [String: Any]?
    public var files: [URL?]?
    public var responsePreprocessor: DataPreprocessor?
    
    // 处理下载的文件
    public var destination: DownloadRequest.Destination? = nil
    
    public var afRequest: Request? {
        didSet {
            if self.afRequest != nil {
                if self.needRequestState == .cancelled {
                    self.cancel()
                } else if self.needRequestState == .suspended {
                    self.suspend()
                } else if self.needRequestState == .resumed {
                    self.resume()
                }
            }
        }
    }
    
    public var needRequestState: Request.State?
    
    public var uploadProgress: ProgressHandler?
    
    public var downloadProgress: ProgressHandler?
    
    
    public func url() throws -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = self.scheme()
        urlComponents.host = self.host()
        urlComponents.path = self.path()
        urlComponents.queryItems = self.query?.map({ k,v in
            return URLQueryItem(name: k, value: v)
        })
        return try urlComponents.asURL()
    }
    
}

// Control
extension NWRequest {
    
    public func cancel() {
        if self.afRequest != nil {
            self.afRequest?.cancel()
        } else {
            self.needRequestState = .cancelled
        }
    }
    
    public func resume() {
        if self.afRequest != nil {
            self.afRequest?.resume()
        } else {
            self.needRequestState = .resumed
        }
    }
    
    public func suspend() {
        if self.afRequest != nil {
            self.afRequest?.suspend()
        } else {
            self.needRequestState = .suspended
        }
    }
    
}


protocol NWRequestTypesProtocol {
    static var types: [Any.Type] { get }
}

extension NWRequestTypesProtocol {
    static var types: [Any.Type] {
        get {
            return []
        }
    }
}


extension URLRequest: NWRequestTypesProtocol {
    
    struct RuntimeKey {
        static let nw_request = UnsafeRawPointer.init(bitPattern: "nw_request".hashValue)!
    }
    
    var nwRequest: Any? {
        get {
            return objc_getAssociatedObject(self, URLRequest.RuntimeKey.nw_request)
        }
        set {
            objc_setAssociatedObject(self, URLRequest.RuntimeKey.nw_request, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func asNWRequest<T: Json>() -> NWRequest<T>? {
        return self.nwRequest as? NWRequest<T>
    }
    
    func needLogin() -> Bool {
        if self.nwRequest == nil { return false }
        for t in URLRequest.types {
            if t == type(of: self.nwRequest) {
                return true
            }
        }
        return false
    }
    
}
