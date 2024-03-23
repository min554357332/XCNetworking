//
//  NWAdapter.swift
//  networking
//
//  Created by mac on 2024/1/25.
//

import Foundation
import Alamofire

public typealias NWKernelResult = Result<Data,NWError>

public typealias NWResult<T: Json> = Result<T,NWError>

typealias NWContinuation = UnsafeContinuation<NWKernelResult, Never>

public protocol Json: Codable {
    static func decode<T: Json>(json: [AnyHashable: Any]) throws -> T
    static func decode<T: Json>(data: Data) throws -> T
    func encode() throws -> [AnyHashable: Any]
}

public extension Json {
    static func decode<T: Json>(json: [AnyHashable: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        let obj = try JSONDecoder().decode(T.self, from: data)
        return obj
    }
    
    static func decode<T: Json>(data: Data) throws -> T {
        let obj = try JSONDecoder().decode(T.self, from: data)
        return obj
    }
    
    func encode() throws -> [AnyHashable: Any] {
        let data = try JSONEncoder().encode(self)
        let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
        return json ?? [:]
    }
}

class NWAdapter {
    static func fire<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        let result = await NWKernel.fire(request)
        switch result {
        case .success(let data):
            do {
                let model = try JSONDecoder().decode(T.self, from: data)
                return .success(model)
            } catch {
                return .failure(NWError(NWResponseStatus(statusCode: 10003),
                                        headers: NWHeaders(request.header?.map({ key, val in
                    return [(key, val)]
                }) as! [(String, String)]),
                                        reason: error.localizedDescription))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public static func upload<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        let result = await NWKernel.upload(request)
        switch result {
        case .success(let data):
            do {
                let model = try JSONDecoder().decode(T.self, from: data)
                return .success(model)
            } catch {
                return .failure(NWError(NWResponseStatus(statusCode: 10003),
                                        reason: error.localizedDescription))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public static func download<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        let result = await NWKernel.download(request)
        switch result {
        case .success(let data):
            do {
                let model = try JSONDecoder().decode(T.self, from: data)
                return .success(model)
            } catch {
                return .failure(NWError(NWResponseStatus(statusCode: 10003),
                                        reason: error.localizedDescription))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

