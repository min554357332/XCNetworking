import Alamofire
import Foundation

let NWKernel = NWAlamofireKernel.share


class NWAlamofireKernel {
    static let share = NWAlamofireKernel()
    private init() {}
}

extension NWAlamofireKernel {
    
    public func fire<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWKernelResult {
        do {
            let dataRequest = try self.dataRequest(request)
            return await withUnsafeContinuation { continuation in
                self.dataResume(
                    dataRequest,
                    request: request,
                    continuation: continuation
                )
            }
        } catch {
            return .failure(NWError(NWResponseStatus(statusCode: 10002),
                                    reason: error.localizedDescription))
        }
    }
    
    public func upload<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWKernelResult {
        do {
            let uploadRequest = try self.uploadRequest(request)
            if request.uploadProgress != nil {
                uploadRequest.uploadProgress(closure: request.uploadProgress!)
            }
            return await withUnsafeContinuation { continuation in
                self.uploadResume(
                    uploadRequest,
                    request: request,
                    continuation: continuation
                )
            }
        } catch {
            return .failure(NWError(NWResponseStatus(statusCode: 10002),
                                    reason: error.localizedDescription))
        }
    }
    
    public func download<T: Json>(
        _ request: NWRequest<T>
    ) async -> NWKernelResult {
        do {
            let downloadRequest = try self.downloadRequest(request)
            if request.downloadProgress != nil {
                downloadRequest.downloadProgress(closure: request.downloadProgress!)
            }
            return await withUnsafeContinuation { continuation in
                self.downloadResume(downloadRequest, request: request, continuation: continuation)
            }
        } catch {
            return .failure(NWError(NWResponseStatus(statusCode: 10002),
                                    reason: error.localizedDescription))
        }
    }
    
    public func stream<T>(
        _ request: NWRequest<T>
    ) async -> NWKernelResult {
        do {
            let streamRequest = try self.streamRequest(request)
            return await withUnsafeContinuation { continuation in
                self.streamResume(streamRequest, request: request, continuation: continuation)
            }
        } catch {
            return .failure(NWError(NWResponseStatus(statusCode: 10002),
                                    reason: error.localizedDescription))
        }
    }
}

private extension NWAlamofireKernel {
    
    func dataResume<T: Json>(
        _ afrequest: DataRequest,
        request: NWRequest<T>,
        continuation: NWContinuation
    ) {
        afrequest.responseData(
            dataPreprocessor: request.responsePreprocessor ?? DataResponseSerializer.defaultDataPreprocessor,
            completionHandler: self.completionHandler(continuation)
        )
    }
    
    func uploadResume<T: Json>(
        _ afrequest: UploadRequest,
        request: NWRequest<T>,
        continuation: NWContinuation
    ) {
        afrequest.responseData(
            dataPreprocessor: request.responsePreprocessor ?? DataResponseSerializer.defaultDataPreprocessor,
            completionHandler: self.completionHandler(continuation)
        )
    }
    
    func downloadResume<T: Json>(
        _ afrequest: DownloadRequest,
        request: NWRequest<T>,
        continuation: NWContinuation
    ) {
        afrequest.responseData(
            dataPreprocessor: request.responsePreprocessor ?? DataResponseSerializer.defaultDataPreprocessor,
            completionHandler: self.downloadCompletionHandler(continuation)
        ).resume()
    }
    
    func streamResume<T: Json>(
        _ afrequest: DataStreamRequest,
        request: NWRequest<T>,
        continuation: NWContinuation
    ) {
        afrequest.responseStream(stream: self.streamCompletionHandler(continuation, request: request)).resume()
    }
    
    func completionHandler(
        _ continuation: NWContinuation
    ) -> (AFDataResponse<Data>) -> Void {
        let handler: (AFDataResponse<Data>) -> Void = { response in
            switch response.result {
            case .success(let data):
                return continuation.resume(returning: .success(data))
            case .failure(let error):
                let responseStatus = NWResponseStatus(statusCode: error.responseCode ?? 10001)
                return continuation.resume(returning: .failure(NWError(responseStatus,
                                                                       reason: error.localizedDescription)))
            }
        }
        return handler
    }
    
    func downloadCompletionHandler(
        _ continuation: NWContinuation
    ) -> (AFDownloadResponse<Data>) -> Void {
        let handler: (AFDownloadResponse<Data>) -> Void = { response in
            switch response.result {
            case .success(let data):
                return continuation.resume(returning: .success(data))
            case .failure(let error):
                let responseStatus = NWResponseStatus(statusCode: error.responseCode ?? 10001)
                return continuation.resume(returning: .failure(NWError(responseStatus,
                                                                       reason: error.localizedDescription)))
            }
        }
        return handler
    }
    
    func streamCompletionHandler<T: Json>(
        _ continuation: NWContinuation,
        request: NWRequest<T>
    ) -> (DataStreamRequest.Stream<Data, Never>) -> Void {
        let handler: (DataStreamRequest.Stream<Data, Never>) -> Void = { response in
            switch response.event {
            case let .stream(result):
                switch result {
                case let .success(data):
                    Task {
                        await request.streamHandler?(data)
                    }
                }
            case let .complete(completion):
                if let error = completion.error {
                    let responseStatus = NWResponseStatus(statusCode: error.responseCode ?? 10001)
                    return continuation.resume(returning: .failure(NWError(responseStatus,
                                                                           reason: error.localizedDescription)))
                } else if let response = completion.response, response.statusCode != NWResponseStatus.ok.code {
                    let responseStatus = NWResponseStatus(statusCode: response.statusCode)
                    return continuation.resume(returning: .failure(NWError(responseStatus,
                                                                           reason: NWResponseStatus(statusCode: response.statusCode).reasonPhrase)))
                } else if let response = completion.response, response.statusCode == NWResponseStatus.ok.code  {
                    return continuation.resume(returning: .success(Data()))
                } else {
                    return continuation.resume(returning: .failure(NWError(.badRequest,
                                                                           reason: NWResponseStatus.badRequest.reasonPhrase)))
                }
            }
        }
        return handler
    }
}

private extension NWAlamofireKernel {
    func dataRequest<T: Json>(
        _ request: NWRequest<T>
    ) throws -> DataRequest {
        let url = try request.url()
        let header = if request.header != nil {
            HTTPHeaders(request.header!)
        } else {
            HTTPHeaders()
        }
        let afRequest = AF.request(
            url,
            method: HTTPMethod(rawValue: request.method().rawValue),
            parameters: request.body,
            encoding: request.encoding,
            headers: header,
            interceptor: request.interceptors(),
            requestModifier: { req in
                try self.requestModifier(request, urlRequest: &req)
            }
        )
        
        request.afRequest = afRequest
        return afRequest
    }
    
    func uploadRequest<T: Json>(
        _ request: NWRequest<T>
    ) throws -> UploadRequest {
        let url = try request.url()
        let header = if request.header != nil {
            HTTPHeaders(request.header!)
        } else {
            HTTPHeaders()
        }
        /*
         usingThreshold
         大于此值:
            文件按此值读入内存进行流传输
         小于此值:
            文件会被全部读入内存进行传输
         */
        let afRequest = AF.upload(
            multipartFormData: { formData in
            
        },
            to: url,
            usingThreshold: MultipartFormData.encodingMemoryThreshold,
            method: HTTPMethod(rawValue: request.method().rawValue),
            headers: header,
            interceptor: request.interceptors(),
            fileManager: FileManager.default,
            requestModifier: { req in
                try self.requestModifier(request, urlRequest: &req)
            }
        )
        request.afRequest = afRequest
        return afRequest
    }
    
    func downloadRequest<T: Json>(
        _ request: NWRequest<T>
    ) throws -> DownloadRequest {
        let url = try request.url()
        let header = if request.header != nil {
            HTTPHeaders(request.header!)
        } else {
            HTTPHeaders()
        }
        let afRequest = AF.download(
            url,
            method: HTTPMethod(rawValue: request.method().rawValue),
            parameters: request.body,
            encoding: request.encoding,
            headers: header,
            interceptor: request.interceptors(),
            requestModifier: { req in
                try self.requestModifier(request, urlRequest: &req)
            },
            to: request.destination
        )
        request.afRequest = afRequest
        return afRequest
    }
    
    func streamRequest<T: Json>(
        _ request: NWRequest<T>
    ) throws -> DataStreamRequest {
        let url = try request.url()
        let header = if request.header != nil {
            HTTPHeaders(request.header!)
        } else {
            HTTPHeaders()
        }
        
        if request.args == nil {
            let afRequest = AF.streamRequest(
                url,
                method: HTTPMethod(rawValue: request.method().rawValue),
                headers: header,
                automaticallyCancelOnStreamError: true,
                interceptor: request.interceptors()
            ) { req in
                try self.requestModifier(request, urlRequest: &req)
            }
            return afRequest
        } else {
            let afRequest = AF.streamRequest(
                url,
                method: HTTPMethod(rawValue: request.method().rawValue),
                parameters: request.args!,
                encoder: JSONParameterEncoder.default,
                headers: header,
                automaticallyCancelOnStreamError: true,
                interceptor: request.interceptors()
            ) { req in
                try self.requestModifier(request, urlRequest: &req)
            }
            return afRequest
        }
        
        
    }
}

private extension NWAlamofireKernel {
    func requestModifier<T: Json>(
        _ request: NWRequest<T>,
        urlRequest: inout URLRequest
    ) throws {
        urlRequest.timeoutInterval = request.timeout()
        urlRequest.nwRequest = request
        request.header = urlRequest.headers.dictionary
        try request.requestModifier?(&urlRequest)
    }
}
