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
    
    override init() {
        super.init()
        setupUIKitHooks()
    }

    internal func setupUIKitHooks() {
        swizzle(forClass: UIViewController.self,
                original: #selector(UIViewController.viewDidAppear(_:)),
                new: #selector(UIViewController.amp__viewDidAppear)
        )
        
        swizzle(forClass: UIViewController.self,
                original: #selector(UIViewController.viewDidDisappear(_:)),
                new: #selector(UIViewController.amp__viewDidDisappear)
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
    
    internal func captureScreen() {
       // var rootController = viewIfLoaded?.window?.rootViewController
        printViewHierarchy(self.view, indent: 0)
    }
    
    internal func printViewHierarchy(_ view: UIView, indent: Int) {
        let indentation = String(repeating: " ", count: indent)
        //print("**********Print View Hierarchy**********")
        //print("\(indentation)\(view)")
        print("********************")
        view.layer.animationKeys()?.forEach({ key in
            print(key)
        })
        for subview in view.subviews {
            printViewHierarchy(subview, indent: indent + 4)
        }
    }
    
    @objc internal func amp__viewDidAppear(animated: Bool) {
        captureScreen()
        // it looks like we're calling ourselves, but we're actually
        // calling the original implementation of viewDidAppear since it's been swizzled.
        amp__viewDidAppear(animated: animated)
    }
    
    @objc internal func amp__viewDidDisappear(animated: Bool) {
        // call the original method first
        amp__viewDidDisappear(animated: animated)
        // the VC should be gone from the stack now, so capture where we're at now.
        captureScreen()
    }
}
