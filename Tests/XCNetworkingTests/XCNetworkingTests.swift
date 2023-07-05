import XCTest
@testable import XCNetworking

final class XCNetworkingTests: XCTestCase {
    func testExample() async {
        let result :Result<TestModel, Error> = await NW.fire(/* input Request */)
        switch result {
        case .success(let success):
            print("success")
        case .failure(let failure):
            print("failure")
        }
    }
}

struct TestModel: Codable {
    let name: String
    let age: Int
}
