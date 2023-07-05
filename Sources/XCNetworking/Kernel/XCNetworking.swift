import Alamofire

let NWKernel = XCNetworkingKernel.share

class XCNetworkingKernel {
    static let share = XCNetworkingKernel()
    private init() {}
}
