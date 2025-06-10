//
//  SwiftUIExtensions.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 5/23/25.
//

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, macOS 10.15, watchOS 6.0, *)
public struct IgnoreInteractionEventModifier: ViewModifier {
    let rageClick: Bool
    
    public func body(content: Content) -> some View {
        content
            .background(
                IgnoreInteractionViewRepresentable(rageClick: rageClick)
                    .frame(width: 0, height: 0)
                    .hidden()
            )
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, watchOS 6.0, *)
private struct IgnoreInteractionViewRepresentable: UIViewRepresentable {
    let rageClick: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        
        // Apply the ignore settings to the superview when the view is added to hierarchy
        DispatchQueue.main.async {
            if let superview = view.superview {
                superview.amp_ignoreInteractionEvent(rageClick: rageClick)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, watchOS 6.0, *)
public extension View {
    /// Mark this view to be ignored for specific interaction events
    /// - Parameter rageClick: Whether to ignore rage click detection for this view
    func amp_ignoreInteractionEvent(rageClick: Bool = false) -> some View {
        self.modifier(IgnoreInteractionEventModifier(rageClick: rageClick))
    }
}

#endif 
