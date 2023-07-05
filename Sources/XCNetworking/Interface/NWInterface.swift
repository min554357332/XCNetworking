//
//  NWInterface.swift
//  
//
//  Created by 大江山岚 on 2023/7/5.
//

import Foundation

typealias ProgressHandler = ((Progress)->())?


public class NWInterface {
    public static func fire<Successful: Codable, Failure: Error>() async -> Result<Successful,Failure> {
        let json :[String: Any] = ["name":"张三","age": 18]
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            let result = try JSONDecoder().decode(Successful.self, from: data)
            return .success(result)
        } catch {
            return .failure(NWError(.badRequest) as! Failure)
        }
    }
}
