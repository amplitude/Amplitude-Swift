import Foundation

protocol DelayedEventsUploading: AnyObject {
    @discardableResult
    func upload(_ body: DelayedRequestBody,
                completion: @escaping (Result<Int, Error>) -> Void) -> URLSessionDataTask?
}

class DelayedEventsHttpClient: DelayedEventsUploading {
    let configuration: Configuration
    let session: URLSession
    let logger: (any Logger)?

    init(configuration: Configuration) {
        self.configuration = configuration
        self.logger = configuration.loggerProvider
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpMaximumConnectionsPerHost = 2
        sessionConfiguration.urlCache = nil
        self.session = URLSession(configuration: sessionConfiguration)
    }

    func getUrl() -> String {
        if let url = configuration.serverUrl, !url.isEmpty {
            return url.hasSuffix("/") ? url + "delayed" : url + "/delayed"
        }
        return configuration.serverZone == .EU
            ? Constants.EU_DELAYED_API_HOST
            : Constants.DELAYED_API_HOST
    }

    @discardableResult
    func upload(_ body: DelayedRequestBody,
                completion: @escaping (Result<Int, Error>) -> Void) -> URLSessionDataTask? {
        guard let requestUrl = URL(string: getUrl()) else {
            completion(.failure(HttpClient.Exception.invalidUrl(url: getUrl())))
            return nil
        }
        var request = URLRequest(url: requestUrl, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return nil
        }
        let backgroundTaskCompletion = VendorSystem.current.beginBackgroundTask()
        let task = session.uploadTask(with: request, from: data) { [logger] data, response, error in
            if let error = error {
                logger?.error(message: "Delayed events request failed: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 1..<300:
                    completion(.success(httpResponse.statusCode))
                default:
                    completion(.failure(HttpClient.Exception.httpError(code: httpResponse.statusCode,
                                                                       data: data)))
                }
            }
            backgroundTaskCompletion?()
        }
        task.resume()
        return task
    }
}
