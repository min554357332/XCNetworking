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
    
    public var args: Encodable?
    
    public init() {}
    
    public typealias ProgressHandler = (Progress) -> Void
    public typealias RequestModifier = (inout URLRequest) throws -> Void
    public typealias StreamHandler = (Data) async -> Void
    
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
    public var encoding: ParameterEncoding = JSONEncoding.default
    public var interceptor: NWInterceptor?
    
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
    
    
    public var requestModifier: RequestModifier?
    
    public var needRequestState: Request.State?
    
    public var uploadProgress: ProgressHandler?
    
    public var downloadProgress: ProgressHandler?
    
    public var streamHandler: StreamHandler?
    
    
    public func url() throws -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = self.scheme()
        if self.host().hasPort() {
            let deconstruction = self.host().components(separatedBy: ":")
            urlComponents.host = deconstruction[0]
            urlComponents.port = Int(deconstruction[1])
        } else {
            urlComponents.host = self.host()
        }
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



extension URLRequest {
    private struct Holder {
        static var _nwRequestProperty = [String:Any]()
    }
    
    public var nwRequest: Any? {
        get {
            return Holder._nwRequestProperty[self.debugDescription]
        }
        set {
            Holder._nwRequestProperty[self.debugDescription] = newValue
        }
    }
}

extension String {
    func hasPort() -> Bool {
        return self.contains(":")
    }
}
