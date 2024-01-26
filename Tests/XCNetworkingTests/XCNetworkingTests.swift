import XCTest
import Alamofire
@testable import networking
@testable import Logging

final class XCNetworkingTests: XCTestCase {
    func testData() async {
        let request = BaseRequest<BaseModel>()
        let result = await nw.fire(request)
        switch result {
        case .success(let model):
            let msg = if model.code == 0 {
                model.data?.autopay ?? "成功"
            } else {
                model.msg ?? "Error"
            }
            Logger(label: "test").info(.init(stringLiteral: msg))
        case .failure(let error):
            Logger(label: "test").error(.init(stringLiteral: error.reason))
        }
    }
    
    func testUpload() async {
        let file_url = Bundle.main.url(forResource: "xxx", withExtension: "png")
        let request = BaseRequest<BaseModel>()
        request.files = [file_url]
        request.uploadProgress = self.upload
        let result = await nw.upload(request)
        switch result {
        case .success(let model):
            Logger(label: "test").info(.init(stringLiteral: "成功"))
        case .failure(let error):
            Logger(label: "test").error(.init(stringLiteral: error.reason))
        }
    }
    func upload(progress: Progress) {
        Logger(label: "test").info(.init(stringLiteral: "\(progress.totalUnitCount / progress.completedUnitCount)"))
    }
    
    func testDownload() async {
        let request = BaseRequest<BaseModel>()
        request.downloadProgress = self.download
        let result = await nw.download(request)
        switch result {
        case .success(let model):
            Logger(label: "test").info(.init(stringLiteral: "成功"))
        case .failure(let error):
            Logger(label: "test").error(.init(stringLiteral: error.reason))
        }
    }
    func download(progress: Progress) {
        Logger(label: "test").info(.init(stringLiteral: "\(progress.totalUnitCount / progress.completedUnitCount)"))
    }
}


class BaseRequest<T: Json>: NWRequest<T> {
    
    override func host() -> String {
        return "lightapi.gr77.cn"
    }
    
    override func path() -> String {
        return "/light/v1/user_info"
    }
    
    override func method() -> NWMethod {
        return .POST
    }
    
    override func interceptors() -> NWInterceptor? {
        return BaseRequestInterceptor()
    }
}

class BaseRequestInterceptor: NWInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("635832b8-402f-4112-8803-9312961f9510", forHTTPHeaderField: "token")
        request.addValue("9bcd60b7794cb1fed055c789fe1d93be", forHTTPHeaderField: "sign")
        request.addValue("21", forHTTPHeaderField: "version")
        request.addValue("ios", forHTTPHeaderField: "oem")
        request.addValue("iPhone X", forHTTPHeaderField: "brand")
        request.addValue("gf", forHTTPHeaderField: "qudao")
        request.addValue("2", forHTTPHeaderField: "v2")
        completion(.success(request))
    }
}

// MARK: - BaseModel
struct BaseModel: Json {
    let code: Int?
    let data: UserinfoModel?
    let msg: String?
}

// MARK: - UserinfoModel
struct UserinfoModel: Json {
    let allnum: Int?
    let autopay: String?
    let code, contactEmail, email, expireDate: String?
    let expireTimestamp, id: Int?
    let ip: String?
    let isNewer: Int?
    let kefu: String?
    let openBoxTimes: Int?
    let payHTML: String?
    let phone: String?
    let pointBalance: Int?
    let privacyAgreement, problem: String?
    let share: String?
    let shareQrcode: String?
    let userAgreement: String?
    let username: String?
    let vip: Int?

    enum CodingKeys: String, CodingKey {
        case allnum, autopay, code
        case contactEmail = "contact_email"
        case email
        case expireDate = "expire_date"
        case expireTimestamp = "expire_timestamp"
        case id, ip
        case isNewer = "is_newer"
        case kefu
        case openBoxTimes = "open_box_times"
        case payHTML = "pay_html"
        case phone
        case pointBalance = "point_balance"
        case privacyAgreement = "privacy_agreement"
        case problem, share
        case shareQrcode = "share_qrcode"
        case userAgreement = "user_agreement"
        case username, vip
    }
}
