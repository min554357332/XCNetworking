import XCTest
import Alamofire
@testable import networking
@testable import Logging

final class XCNetworkingTests: XCTestCase {
    func testSteam() async {
        let req = XCTee<Model>(RequestModel(query: "今天几号"))
        req.streamHandler = self.streamHandler
        let result = await nw.stream(req)
        switch result {
        case .success:
            print(1)
        case .failure(let failure):
            print(failure)
        }
    }
    
    func streamHandler(_ result: Data) {
        let string = String(data: result, encoding: .utf8)
        print(string)
    }
}

struct RequestModel: Json {
    let query: String
}

struct Model: Json {
    
}

class BaseRequest<T: Json>: NWRequest<T> {
    
    override func scheme() -> String {
        return "http"
    }
    
    override func host() -> String {
        return "localhost:8888"
    }
    
    override func method() -> NWMethod {
        return .POST
    }
    
    override func interceptors() -> NWInterceptor? {
        return BaseRequestInterceptor()
    }
}

class XCTee<T: Json>: BaseRequest<T> {
    override func path() -> String {
        return "/api/v1/completions"
    }
    
    override func timeout() -> TimeInterval {
        return 300
    }
    
    override func interceptors() -> (any NWInterceptor)? {
        return BaseRequestInterceptor()
    }
    
    init(
        _ args: Encodable
    ) {
        super.init()
        self.args = args
    }
}

class BaseRequestInterceptor: NWInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(testToken, forHTTPHeaderField: "Authorization")
        completion(.success(request))
    }
}

let testToken = """
"""
