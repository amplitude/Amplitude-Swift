//
//  HttpClient.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class HttpClient {
    let configuration: Configuration
    internal let session: URLSession

    init(configuration: Configuration) {
        self.configuration = configuration
        // an exclusive ephemeral session avoids contention (fewer request timeouts)
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        // add some throughput
        sessionConfiguration.httpMaximumConnectionsPerHost = 2
        // avoid keeping app background task alive for too long
        sessionConfiguration.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: sessionConfiguration)
    }

    func upload(events: String, completion: @escaping (_ result: Result<Int, Error>) -> Void) -> URLSessionDataTask? {
        var sessionTask: URLSessionDataTask?
        do {
            let request = try getRequest()
            let requestData = getRequestData(events: events)

            sessionTask = session.uploadTask(with: request, from: requestData) { data, response, error in
                if error != nil {
                    completion(.failure(error!))
                } else if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 1..<300:
                        completion(.success(httpResponse.statusCode))
                    default:
                        completion(.failure(Exception.httpError(code: httpResponse.statusCode, data: data)))
                    }
                }
            }
            sessionTask!.resume()
        } catch {
            completion(.failure(Exception.httpError(code: 500, data: nil)))
        }
        return sessionTask
    }

    func getUrl() -> String {
        if let url = configuration.serverUrl, !url.isEmpty {
            return url
        }
        if configuration.serverZone == ServerZone.EU {
            return configuration.useBatch ? Constants.EU_BATCH_API_HOST : Constants.EU_DEFAULT_API_HOST
        }
        return configuration.useBatch ? Constants.BATCH_API_HOST : Constants.DEFAULT_API_HOST
    }

    func getRequest() throws -> URLRequest {
        let url = getUrl()
        guard let requestUrl = URL(string: url) else {
            throw Exception.invalidUrl(url: url)
        }
        var request = URLRequest(url: requestUrl, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func getRequestData(events: String) -> Data? {
        let apiKey = configuration.apiKey
        var requestPayload = """
            {"api_key":"\(apiKey)","events":\(events)
            """
        if let minIdLength = configuration.minIdLength {
            requestPayload += """
                ,"options":{"min_id_length":\(minIdLength)}
                """
        }
        requestPayload += "}"
        return requestPayload.data(using: .utf8)
    }
}

extension HttpClient {
    enum HttpStatus: Int {
        case SUCCESS = 200
        case BAD_REQUEST = 400
        case TIMEOUT = 408
        case PAYLOAD_TOO_LARGE = 413
        case TOO_MANY_REQUESTS = 429
        case FAILED = 500
    }

    enum Exception: Error {
        case invalidUrl(url: String)
        case httpError(code: Int, data: Data?)
    }
}
