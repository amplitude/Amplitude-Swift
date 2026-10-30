//
//  AnalyticsHttpClient.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

#if AMPLITUDE_DISABLE_UIKIT
@_spi(Internal) import AmplitudeCoreNoUIKit
#else
@_spi(Internal) import AmplitudeCore
#endif

class AnalyticsHttpClient {
    let configuration: Configuration
    let httpClient: any HttpClient
    let logger: (any Logger)?
    let diagnostics: Diagnostics
    let callbackQueue: DispatchQueue

    private lazy var dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter
    }()

    init(configuration: Configuration, diagnostics: Diagnostics, callbackQueue: DispatchQueue? = nil) {
        self.configuration = configuration
        self.diagnostics = diagnostics
        self.logger = configuration.loggerProvider
        self.callbackQueue = callbackQueue ?? .global()

        self.httpClient = configuration.httpClient ?? URLSessionHttpClient(session: Self.makeSession())
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    func upload(events: String, completion: @escaping (_ result: Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
        let backgroundTaskCompletion = VendorSystem.current.beginBackgroundTask()
        do {
            let (requestData, isGzipEncoded) = getRequestData(events: events)
            var request = try getRequest(isGzipEncoded: isGzipEncoded)
            request.httpBody = requestData
            let requestCompletion: @Sendable (Data?, URLResponse?, Error?) -> Void = { [callbackQueue, configuration, logger] data, response, error in
                callbackQueue.async {
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain {
                            switch nsError.code {
                            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost, NSURLErrorAppTransportSecurityRequiresSecureConnection, NSURLErrorNotConnectedToInternet, NSURLErrorBadURL:
                                logger?.error(message: "Conection failed with error: \(error.localizedDescription), marking offline")
                                configuration.offline = true
                            default:
                                logger?.error(message: "Request failed with error: \(error.localizedDescription)")
                            }
                        }
                        completion(.failure(error))
                    } else if let httpResponse = response as? HTTPURLResponse {
                        switch httpResponse.statusCode {
                        case 1..<300:
                            completion(.success(httpResponse.statusCode))
                            logger?.debug(message: "Successfully completed request")
                        default:
                            let response = String(data: data ?? Data(), encoding: .utf8) ?? ""
                            logger?.error(message: "Response failed with code\(httpResponse.statusCode): \(response)")
                            completion(.failure(Exception.httpError(code: httpResponse.statusCode, data: data)))
                        }
                    } else {
                        completion(.failure(URLError(.badServerResponse)))
                    }
                    backgroundTaskCompletion?()
                }
            }
            return httpClient.send(request, completion: requestCompletion)
        } catch {
            logger?.debug(message: "Failed to construct request")
            completion(.failure(Exception.httpError(code: 500, data: nil)))
            backgroundTaskCompletion?()
        }
        return nil
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

    func getRequest(isGzipEncoded: Bool) throws -> URLRequest {
        let url = getUrl()

        let requestUrl: URL?
#if compiler(>=5.9)
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            requestUrl = URL(string: url, encodingInvalidCharacters: false)
        } else {
            requestUrl = URL(string: url)
        }
#else
        requestUrl = URL(string: url)
#endif

        guard let requestUrl else {
            throw Exception.invalidUrl(url: url)
        }
        var request = URLRequest(url: requestUrl, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if isGzipEncoded {
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        }
        return request
    }

    func getRequestData(events: String) -> (data: Data?, isGzipEncoded: Bool) {
        let apiKey = configuration.apiKey
        let clientUploadTime: String = dateFormatter.string(from: getDate())
        var requestPayload = """
            {"api_key":"\(apiKey)","client_upload_time":"\(clientUploadTime)","events":\(events)
            """
        if let minIdLength = configuration.minIdLength {
            requestPayload += """
                ,"options":{"min_id_length":\(minIdLength)}
                """
        }
        if let diagnosticsInfo = diagnostics.extractDiagnosticsToString(), !diagnosticsInfo.isEmpty {
            requestPayload += """
                ,"request_metadata":{"sdk":\(diagnosticsInfo)}
                """
        }
        requestPayload += "}"
        guard let data = requestPayload.data(using: .utf8) else {
            return (nil, false)
        }

        if shouldCompressUploadBody {
            do {
                return (try data.gzipped(), !data.isEmpty)
            } catch {
                logger?.error(message: "Error compressing request body: \(error)")
                return (data, false)
            }
        } else {
            return (data, false)
        }
    }

    var shouldCompressUploadBody: Bool {
        // Custom servers may not support gzip compression- only enable it if opted in.
        if let serverUrl = configuration.serverUrl, !serverUrl.isEmpty {
            return configuration.enableRequestBodyCompression
        } else {
            return true
        }
    }

    func getDate() -> Date {
        return Date()
    }
}

extension AnalyticsHttpClient {
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
