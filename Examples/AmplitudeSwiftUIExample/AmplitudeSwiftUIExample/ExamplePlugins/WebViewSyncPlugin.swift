//
//  WebViewSyncPlugin.swift
//  AmplitudeSwiftUIExample
//
//  Created by Chris Leonavicius on 1/9/25.
//

import AmplitudeSwift
import ObjectiveC
import WebKit

class WebViewSyncPlugin: NSObject, Plugin {

    let type = PluginType.utility

    private let webviews = NSHashTable<WKWebView>.weakObjects()

    private static let swizzleWebViewInitializer: Void = {
        func swizzle(class cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
            let originalMethod = class_getInstanceMethod(cls, originalSelector)
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)

            guard let originalMethod, let swizzledMethod else { return }

            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        swizzle(class: WKWebView.self,
                originalSelector: #selector(WKWebView.init(frame:configuration:)),
                swizzledSelector: #selector(WKWebView.amp_init(frame:configuration:)))

        swizzle(class: WKWebView.self,
                originalSelector: #selector(WKWebView.init(coder:)),
                swizzledSelector: #selector(WKWebView.amp_init(coder:)))
    }()

    private weak var amplitude: Amplitude?

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude

        Self.swizzleWebViewInitializer
        Self.registerPlugin(self)
        DispatchQueue.main.async { [weak self] in
            self?.injectConfigInAllWebviews()
        }
    }

    func execute(event: BaseEvent) -> BaseEvent? {
        return event
    }

    @MainActor
    func onAttachWebView(webview: WKWebView) {
        attach(to: webview)
        injectConfig(in: webview)
    }

    func onUserIdChanged(_ userId: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.injectConfigInAllWebviews()
        }
    }

    func onDeviceIdChanged(_ deviceId: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.injectConfigInAllWebviews()
        }
    }

    func onSessionIdChanged(_ sessionId: Int64) {
        DispatchQueue.main.async { [weak self] in
            self?.injectConfigInAllWebviews()
        }
    }

    func onOptOutChanged(_ optOut: Bool) {
        // no-op
    }

    func teardown() {
        let webviews = Self.registeredWebViews
        Self.unregisterPlugin(self)
        DispatchQueue.main.async {
            webviews.forEach {
                $0.configuration.userContentController.removeScriptMessageHandler(forName: "amp_webview_config_callback")
            }
        }
    }

    deinit {
        teardown()
    }
}

extension WebViewSyncPlugin: WKScriptMessageHandler {

    private func attach(to webView: WKWebView) {
        let userContentController = webView.configuration.userContentController
        if !userContentController.userScripts.contains(where: { $0 === WebViewSyncPlugin.userScript }) {
            userContentController.addUserScript(WebViewSyncPlugin.userScript)
        }
        userContentController.add(self, name: "amp_webview_config_callback")
    }

    private static let userScriptSource =
"""
(function () {
  if (window.amp_webview_config) {
    return;
  }

  var config = null;
  const subscribers = [];

  function subscribe(callback) {
    subscribers.push(callback);
  }

  function unsubscribe(callback) {
    subscribers = subscribers.filter((sub) => sub !== callback);
  }

  function getConfig() {
    return config;
  }

  function updateConfig(updatedConfig) {
    config = updatedConfig;
    subscribers.forEach((callback) => {
      callback(config);
    });
  }

  window.amp_webview_config = {
    subscribe,
    unsubscribe,
    getConfig,
    updateConfig,
  };
})();
window.webkit.messageHandlers.amp_webview_config_callback.postMessage(0);
"""

    private static let userScript = WKUserScript(source: userScriptSource,
                                                 injectionTime: .atDocumentStart,
                                                 forMainFrameOnly: false)

    @MainActor
    private func injectConfigInAllWebviews() {
        WebViewSyncPlugin.webviews.allObjects.forEach { injectConfig(in: $0) }
    }

    @MainActor
    private func injectConfig(in webview: WKWebView, frameInfo: WKFrameInfo? = nil) {
        guard let amplitude = amplitude else {
            return
        }

        let config = NSMutableDictionary()
        config["api_key"] = amplitude.configuration.apiKey
        config["user_id"] = amplitude.getUserId()
        config["device_id"] = amplitude.getDeviceId()
        config["session_id"] = amplitude.getSessionId()

        guard let configJsonData = try? JSONSerialization.data(withJSONObject: config),
              let configJsonString = String(data: configJsonData, encoding: .utf8) else {
            return
        }

        let script = "window.amp_webview_config.updateConfig(\(configJsonString));"

        if #available(iOS 14.0, *) {
            webview.evaluateJavaScript(script, in: frameInfo, in: .page) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Error injecting script: \(error)")
                }
            }
        } else {
            webview.evaluateJavaScript(script) { result, error in
                if let error {
                    print("Error injecting script: \(error)")
                }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let webview = message.webView else {
            return
        }
        injectConfig(in: webview, frameInfo: message.frameInfo)
    }
}

extension WebViewSyncPlugin {

    private static let lock = NSLock()
    private static let webviews = NSHashTable<WKWebView>.weakObjects()
    private static var plugins: [WebViewSyncPlugin] = []

    private static func registerPlugin(_ plugin: WebViewSyncPlugin) {
        lock.withLock {
            plugins.append(plugin)
        }
    }

    private static func unregisterPlugin(_ plugin: WebViewSyncPlugin) {
        lock.withLock {
            plugins.removeAll { $0 === plugin }
        }
    }

    @MainActor
    fileprivate static func registerWebview(_ webview: WKWebView) {
        var activePlugins: [WebViewSyncPlugin]?
        lock.withLock {
            activePlugins = plugins
            webviews.add(webview)
        }

        activePlugins?.forEach { $0.onAttachWebView(webview: webview) }
    }

    private static var registeredWebViews: [WKWebView] {
        return lock.withLock {
            return webviews.allObjects
        }
    }
}

extension WKWebView {

    @objc func amp_init(coder: NSCoder) -> Self? {
        let webview = amp_init(coder: coder)

        if let webview {
            WebViewSyncPlugin.registerWebview(webview)
        }

        return webview
    }

    @objc func amp_init(frame: CGRect, configuration: WKWebViewConfiguration) -> Self {
        let webview = amp_init(frame: frame, configuration: configuration)

        WebViewSyncPlugin.registerWebview(webview)

        return webview
    }
}
