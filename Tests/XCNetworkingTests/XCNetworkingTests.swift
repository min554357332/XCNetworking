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
    // (Result<Data,NWError>) -> Void
    func streamHandler(_ result: Data) {
        let string = String(data: result, encoding: .utf8)
        print(string)
    }
    var expectation: XCTestExpectation!
    func testAaa() {
        /*
         curl --location 'http://18.220.53.146:10087/api/v1/search/stream' \
         -X POST \
         -H 'Content-Type: application/json' \
         -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo1NTQzLCJyZWdpc3Rlcl90eXBlIjoicGhvbmUiLCJhcHBfbmFtZSI6IkNoaXRDaGF0X2lPUyIsInRva2VuX2lkIjoiYjUyNWIxMzItZmM2My00YWMwLTgxN2QtMjdmZjczNDZlYzliIiwiaXNzIjoiZGV2Lndpc2Vob29kLmFpIiwiYXVkIjpbIiJdLCJleHAiOjE3NDI2OTUzNzgsIm5iZiI6MTcxMTU5MTM3OCwiaWF0IjoxNzExNTkxMzc4fQ.5ipqxQhCJKeYCZ2ezNZlJrvb7Fc_R1bcZYuIzmEHZaU' \
         -d '{"query": "今天几号"}'
         */
        let url = "http://18.220.53.146:10087/api/v1/search/stream"
        self.expectation = expectation(description: "Login ···")
        let model = RequestModel(query: "今天几号")
        AF.streamRequest(
            url,
            method: .post,
            parameters: model,
            encoder: JSONParameterEncoder.default,
            headers: HTTPHeaders(["Authorization":testToken]),
            automaticallyCancelOnStreamError: true,
            interceptor: nil,
            requestModifier: nil
        )
        .responseStream { result in
            switch result.event {
            case let .stream(result):
                switch result {
                case let .success(data):
                    let string = String(data: data, encoding: .utf8)
                    print(string)
                }
            case let .complete(completion):
                print(completion)
                self.expectation.fulfill()
            }
        }
        self.wait(for: [self.expectation], timeout: 300)
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
        return "18.220.53.146:10087"
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
        return "/api/v1/search/stream"
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
Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo1NTQzLCJyZWdpc3Rlcl90eXBlIjoicGhvbmUiLCJhcHBfbmFtZSI6IkNoaXRDaGF0X2lPUyIsInRva2VuX2lkIjoiYjUyNWIxMzItZmM2My00YWMwLTgxN2QtMjdmZjczNDZlYzliIiwiaXNzIjoiZGV2Lndpc2Vob29kLmFpIiwiYXVkIjpbIiJdLCJleHAiOjE3NDI2OTUzNzgsIm5iZiI6MTcxMTU5MTM3OCwiaWF0IjoxNzExNTkxMzc4fQ.5ipqxQhCJKeYCZ2ezNZlJrvb7Fc_R1bcZYuIzmEHZaU
"""
