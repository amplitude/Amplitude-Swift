//
//  RageClickExample.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 5/23/25.
//

import Foundation
import AmplitudeSwift

#if os(iOS)
import UIKit
import SwiftUI

// MARK: - Configuration Example

func setupAmplitudeWithRageClickDetection() {
    // Configure rage click options
    let rageClickOptions = RageClickOptions(
        threshold: 3,    // Trigger after 3 clicks
        timeout: 1000    // Within 1 second
    )
    
    let interactionsOptions = InteractionsOptions(rageClick: rageClickOptions)
    
    // Create Amplitude configuration with rage click detection
    let config = Configuration(
        apiKey: "your-api-key",
        interactionsOptions: interactionsOptions
    )
    
    // Initialize Amplitude
    let amplitude = Amplitude(configuration: config)
}

// MARK: - UIKit Example

class ExampleViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a button that might trigger rage clicks
        let button = UIButton(type: .system)
        button.setTitle("Tap Me", for: .normal)
        button.frame = CGRect(x: 100, y: 100, width: 100, height: 50)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(button)
        
        // Create a button that should be ignored for rage click detection
        let ignoredButton = UIButton(type: .system)
        ignoredButton.setTitle("Ignored Button", for: .normal)
        ignoredButton.frame = CGRect(x: 100, y: 200, width: 150, height: 50)
        ignoredButton.addTarget(self, action: #selector(ignoredButtonTapped), for: .touchUpInside)
        
        // Mark this button to be ignored for rage click detection
        ignoredButton.amp_ignoreInteractionEvent(rageClick: true)
        
        view.addSubview(ignoredButton)
    }
    
    @objc func buttonTapped() {
        print("Button tapped - this can trigger rage click detection")
    }
    
    @objc func ignoredButtonTapped() {
        print("Ignored button tapped - this will NOT trigger rage click detection")
    }
}

// MARK: - SwiftUI Example

@available(iOS 13.0, *)
struct ExampleSwiftUIView: View {
    var body: some View {
        VStack(spacing: 20) {
            Button("Tap Me") {
                print("Button tapped - this can trigger rage click detection")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Ignored Button") {
                print("Ignored button tapped - this will NOT trigger rage click detection")
            }
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            // Mark this button to be ignored for rage click detection
            .amp_ignoreInteractionEvent(rageClick: true)
        }
        .padding()
    }
}

// MARK: - Usage Notes

/*
 Rage Click Detection Features:
 
 1. Configuration:
    - threshold: Number of clicks to trigger rage click (minimum 3)
    - timeout: Maximum time window in milliseconds (minimum 1000ms)
 
 2. Detection Logic:
    - Tracks clicks on the same element within a 50pt range
    - Triggers when threshold is reached within timeout period
    - Uses debounce timer to collect additional clicks
    - Automatically generates RageClickEvent with click details
 
 3. Ignoring Views:
    - UIKit: view.amp_ignoreInteractionEvent(rageClick: true)
    - SwiftUI: .amp_ignoreInteractionEvent(rageClick: true)
 
 4. Event Properties:
    - Begin Time: When the first click occurred
    - End Time: When the last click occurred
    - Duration: Time between first and last click
    - Clicks: Array of click coordinates and timestamps
    - Screen Name, Accessibility info, View hierarchy, etc.
 
 5. Supported Interactions:
    - UIControl touch events (buttons, etc.)
    - UITapGestureRecognizer
    - Automatically filters out scroll/zoom gestures
 */

#endif 