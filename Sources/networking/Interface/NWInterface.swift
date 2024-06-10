//
//  NWInterface.swift
//  
//
//  Created by 大江山岚 on 2023/7/5.
//

import Foundation

public typealias nw = NWInterface

public struct NWInterface {
    
    public static func fire<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        return await NWAdapter.fire(request)
    }
    
    public static func upload<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        return await NWAdapter.upload(request)
    }
    
    public static func download<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        return await NWAdapter.download(request)
    }
    
    public static func stream<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWResult<T> {
        return await NWAdapter.stream(request)
    }
}
