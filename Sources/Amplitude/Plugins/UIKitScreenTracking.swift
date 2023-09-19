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
        swizzle(forClass: UIWindow.self,
                original: #selector(UIWindow.sendEvent(_:)),
                new: #selector(UIWindow.amp__sendEvent)
        )

        /*swizzle(forClass: UIScrollView.self,
                original: #selector(UIScrollView.setContentOffset(_:animated:)),
                new:  #selector(UIScrollView.amp__setContentOffset)
        )*/
        
        /*

        swizzle(forClass: UIScrollView.self,
                original: #selector(UIScrollView.setContentOffset(_:animated:)),
                new: #selector(UIScrollView.swizzledSetContentOffset(_:animated:)))
        
        /*swizzle(forClass: UIScrollView.self,
                original: #selector(setter : UIScrollView.contentOffset),
                new: #selector(setter : UIScrollView.swizzledContentOffset))
        */
        swizzle(forClass: UIScrollView.self,
                original: #selector(setter: UIScrollView.contentOffset),
                new: #selector(UIScrollView.swizzledSetContentOffset(_:)))
        //
        */
        /*
        swizzle(forClass: UIResponder.self,
                original: #selector(UIResponder.pressesBegan(_:with:)),
                new: #selector(UIResponder.amp__pressesBegan)
        )
        swizzle(forClass: UIGestureRecognizer.self,
                original: #selector(UIGestureRecognizer.touchesBegan(_:with:)),
                new: #selector(UIGestureRecognizer.amp__touchesBegan)
        )
        swizzle(forClass: UIGestureRecognizer.self,
                original: #selector(UIGestureRecognizer.touchesMoved(_:with:)),
                new: #selector(UIGestureRecognizer.amp__touchesMoved)
        )*/
    }
}

extension UIKitScreenTracking {
    private func swizzle(forClass: AnyClass, original: Selector, new: Selector) {
        guard let originalMethod = class_getInstanceMethod(forClass, original) else { return }
        guard let swizzledMethod = class_getInstanceMethod(forClass, new) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

/*
extension UIScrollView {
    /// The swizzled contentOffset property
       /*@objc public var swizzledContentOffset: CGPoint
           {
           get {
               self.swizzledContentOffset // not recursive, false warning
           }
           set {
               self.swizzledContentOffset = newValue
           }
       }*/

       /// The swizzed ContentOffset method (2 input parameters)
       @objc public func swizzledSetContentOffset(_ contentOffset : CGPoint, animated: Bool)
       {
           NSLog(contentOffset.x.description)
           NSLog(contentOffset.y.description)

           //swizzledSetContentOffset(contentOffset, animated: animated)
       }
       
       /// The swizzed ContentOffset method (1 input setter)
       @objc public func swizzledSetContentOffset(_ contentOffset: CGPoint)
       {
           NSLog(contentOffset.x.description)
           NSLog(contentOffset.y.description)
           //swizzledSetContentOffset(contentOffset) // not recursive
       }
}*/
                
extension UIViewController {
    
    internal func sendToServer(_ viewHierachy: String) {
        //print(viewHierachy)
        //print(UIKitScreenTracking.screenTrackingUrl)
        _ = upload(view: viewHierachy) { result in
        //   print(result)
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
    
    func hexStringFromColor(color: UIColor) -> String {
        let components = color.cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        var b: CGFloat = 0.0
        if (components?.count ?? 0 > 2) {
            b = components?[2] ?? 0.0
        }
        
        let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
        print(hexString)
        return hexString
     }
    
    internal func getViewHierarchy(_ view: UIView, indent: Int) -> String {
        if (view.backgroundColor !== nil) {
            let bgColor : UIColor = view.backgroundColor!
            let bgHexColor = hexStringFromColor(color: bgColor)
            print(bgHexColor)
        }
        
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
        
        /*
         // Add an action to every UIButton within the view's hierarchy
        self.view.traverseHierarchy { view in
            if let button = view as? UIButton {
                button.addTarget(self, action: #selector(self.buttonTouchUpInside), for: .touchUpInside)
            }
        }
        
        // Monitor UIBarButtonItems in the UINavigationBar
        if let items = self.navigationItem.rightBarButtonItems {
            for item in items {
                item.target = self
                item.action = #selector(self.barButtonItemPressed(_:))
            }
        }
        if let leftItems = self.navigationItem.leftBarButtonItems {
            for item in leftItems {
                item.target = self
                item.action = #selector(self.barButtonItemPressed(_:))
            }
        }*/
    }
    
    /*@objc func buttonTouchUpInside(_ sender: UIButton) {
        print("Button with title \(String(describing: sender.currentTitle)) was tapped!")
        print(sender)
    }
    
    @objc func barButtonItemPressed(_ sender: UIBarButtonItem) {
        print("BarButtonItem with title \(String(describing: sender.title)) was pressed!")
        print(sender)
    }*/
}

/*extension UIView {
    func traverseHierarchy(_ closure: (UIView) -> Void) {
        closure(self)
        for subview in subviews {
            subview.traverseHierarchy(closure)
        }
    }
}

extension UIGestureRecognizer {
    
    @objc dynamic func amp__touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.amp__touchesBegan(touches, with: event) // Call the original method
        print("amp__touchesBegan: \(touches)")
    }
    
    @objc dynamic func amp__touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        self.amp__touchesMoved(touches, with: event) // Call the original method
        print("amp__touchesMoved: \(touches)")
    }
}
*/

extension UIWindow {
    @objc func amp__sendEvent(_ event: UIEvent) {
        // Call the original method
        self.amp__sendEvent(event)
        
        // Add your monitoring logic here
        if let touches = event.allTouches {
            for touch in touches {
                if touch.phase == .began {
                    print("Touch began: \(touch)")
                }
            }
        }
    }
}

extension UIResponder {
    @objc func amp__pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Call the original method
        self.amp__pressesBegan(presses, with: event)

        // Your monitoring or additional code for key presses
        for press in presses {
            if let key = press.key {
                print("Key pressed: \(key.characters)")
            }
        }
    }
}

internal func upload(view: String, completion: @escaping (_ result: Result<Int, Error>) -> Void) -> URLSessionDataTask? {
    let session = URLSession.shared
    var sessionTask: URLSessionDataTask?
    do {
            let viewString = view.replacingOccurrences(of: "\'", with: "'").replacingOccurrences(of: "\n", with: "<br>")
            let request = try getRequest()
            var requestPayload = """
                {"viewHierarchy":"\(viewString)"}
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

