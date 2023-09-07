//
//  SessionReplayPlugin.swift
//  Amplitude-Swift
//
//  Created by Alyssa.Yu on 9/6/23.
//

import Foundation
import UIKit

/**
 Example plugin to replicate automatic screen tracking in iOS.
 */

class UIKitScreenTracking: UtilityPlugin {
    internal static var screenTrackingUrl = "http://localhost:8081/session-replay"
    //"https://webhook.site/4e8b7abd-5937-4f01-a909-b4b7c872930a"

    override init() {
        super.init()
        setupUIKitHooks()
    }

    internal func setupUIKitHooks() {
        swizzle(forClass: UIViewController.self,
                original: #selector(UIViewController.viewDidAppear(_:)),
                new: #selector(UIViewController.amp__viewDidAppear)
        )
    }
}

extension UIKitScreenTracking {
    private func swizzle(forClass: AnyClass, original: Selector, new: Selector) {
        guard let originalMethod = class_getInstanceMethod(forClass, original) else { return }
        guard let swizzledMethod = class_getInstanceMethod(forClass, new) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension UIViewController {
    
    internal func sendToServer(_ viewHierachy: String) {
        print(viewHierachy)
        print(UIKitScreenTracking.screenTrackingUrl)
        _ = upload(view: viewHierachy) { result in
           print(result)
        }
    }
    
    internal func captureScreen() {
        //var rootController = viewIfLoaded?.window?.rootViewController
        //print(rootController);
        var viewHierachy = ""
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootView = keyWindow.rootViewController?.view {
            viewHierachy = getViewHierarchy(rootView, indent: 0)
        }
        
        sendToServer(viewHierachy);
    }
    
    internal func getViewHierarchy(_ view: UIView, indent: Int) -> String {
        let indentation = String(repeating: " ", count: indent)
        //print("**********Print View Hierarchy**********")
        var result = "\(indentation)\(view)\n"
        for subview in view.subviews {
            result += getViewHierarchy(subview, indent: indent + 4)
        }
        return result
    }
    
    @objc internal func amp__viewDidAppear(animated: Bool) {
        captureScreen()
        // it looks like we're calling ourselves, but we're actually
        // calling the original implementation of viewDidAppear since it's been swizzled.
        amp__viewDidAppear(animated: animated)
    }
}

    internal func upload(view: String, completion: @escaping (_ result: Result<Int, Error>) -> Void) -> URLSessionDataTask? {
        let session = URLSession.shared
        var sessionTask: URLSessionDataTask?
        do {
            let request = try getRequest()
            var requestPayload = """
                {"viewHierarchy":"\(view)"}
                """
            let requestData = requestPayload.data(using: .utf8)

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

    func getRequest() throws -> URLRequest {
        let url = UIKitScreenTracking.screenTrackingUrl
        guard let requestUrl = URL(string: url) else {
            throw Exception.invalidUrl(url: url)
        }
        var request = URLRequest(url: requestUrl, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

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

