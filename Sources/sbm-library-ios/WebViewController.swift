//
//  WebViewController.swift
//  sbm-library-ios
//
//  Created by Varun on 30/10/23.
//

import Foundation
@preconcurrency import WebKit
import AVFoundation
import UIKit
import SwiftUI

public class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    private lazy var webView: WKWebView = {
        let webConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "iosListener")
        webConfiguration.userContentController = userContentController
        
        // Enable caching
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = true
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        if #available(iOS 14.0, *) {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        return webView
    }()
    var urlString: String?
    var completion: (WebViewCallback) -> Void
    
    public init(urlString: String?, completion: @escaping (WebViewCallback) -> Void) {
        self.urlString = urlString
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        let swipeBack = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe(_:)))
        swipeBack.direction = .right
        self.view.addGestureRecognizer(swipeBack)
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        //        webView.frame = view.bounds
        
        
        
        if let cookies = HTTPCookieStorage.shared.cookies {
            for _ in cookies {
                
            }
        }
        
        //        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        //        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        loadRequestWithCookies(completion: { error in
            if let error = error {
                print("Error loading webView: \(error)")
            }
        })
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //        additionalSafeAreaInsets = UIEdgeInsets(top: -view.safeAreaInsets.top, left: 0, bottom: -view.safeAreaInsets.bottom, right: 0)
    }
    
    @objc func didSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .right {
            handleBackButton()
        }
    }
    
    func handleBackButton() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    func loadRequestWithCookies(completion: @escaping (Error?) -> Void) {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        
        let dispatchGroup = DispatchGroup()
        
        for cookie in cookies {
            dispatchGroup.enter()
            cookieStore.setCookie(cookie) {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            do {
                guard let urlString = self.urlString, let url = URL(string: urlString) else {
                    throw InvalidURLError.invalidURL
                }
                
                let request = URLRequest(url: url)
                self.webView.load(request)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    public func updateAndReload(with urlString: String) {
        self.urlString = urlString
        loadRequestWithCookies { error in
            if let error = error {
                print("Error reloading WebView: \(error)")
            }
        }
    }
    
    public func setCallback(_ callback: @escaping (WebViewCallback) -> Void) {
        self.completion = callback
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error)")
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        let isCameraActionRequiredScript = "typeof capture === 'function'"
        
        webView.evaluateJavaScript(isCameraActionRequiredScript) { result, error in
            if let error = error {
                print("JavaScript evaluation error: \(error)")
            } else if let isFunction = result as? Bool, isFunction {
                self.handleCameraAction()
            } else {
                
            }
        }
    }
    
    func handleCameraAction() {
        requestCameraPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.webView.evaluateJavaScript("takePhoto();")
            } else {
                print("Camera permission denied")
            }
        }
    }
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    private func openURLExternally(_ url: URL, completion: @escaping () -> Void) {
        UIApplication.shared.open(url, options: [:]) { _ in
            completion()
        }
    }
    
    enum InvalidURLError: Error {
        case invalidURL
    }
    
}

extension WebViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "spense_library" {
            if let messageBody = message.body as? String {
                print("Received message from web: \(messageBody)")
                // Handle the message or perform an action based on the message content
            }
        }
    }
}

extension WebViewController {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        // Convert your logic to Swift
        let urlString = url.absoluteString
        
        print(urlString)
        
        if urlString.contains("/redirect?status=") {
            if let status = url.query?.components(separatedBy: "=").last {
                // Call the onRedirect callback and pass the status
                completion(.redirect(status: status))
            }
            decisionHandler(.cancel) // Stop loading since we're handling it
            self.dismiss(animated: true)
            return
        }
        
        if urlString.contains("session-expired") {
            completion(.logout)
            decisionHandler(.cancel) // Stop loading
            self.dismiss(animated: true)
            return
        }
        
        if let host = url.host, host.contains("sbmkyc") {
            self.getPermissions { granted in
                if granted {
                    // Execute user media call once permissions are granted
                    webView.evaluateJavaScript("""
                            navigator.mediaDevices.getUserMedia({ audio: true, video: true })
                              .catch(function(err) {
                                console.log('Media permissions error:', err);
                              });
                            """) { result, error in
                        if let error = error {
                            print("Error evaluating user media JS: \(error)")
                        }
                    }
                } else {
                    print("Camera and microphone permissions not granted.")
                }
            }
        }
        
        // Loop through whitelisted URLs to find a match
        for whitelistedUrl in EnvManager.whitelistedUrls {
            if urlString.contains(whitelistedUrl) || urlString.contains(EnvManager.hostName) {
                // If URL matches whitelisted URL or the environment manager's hostname, load it inside the WebView
                decisionHandler(.allow)
                return
            }
        }
        
        // If URL does not match any condition, open it externally
        openURLExternally(url) {
            decisionHandler(.cancel)
        }
    }
    
    func getPermissions(completion: @escaping (Bool) -> Void) {
        var cameraGranted = false
        var micGranted = false
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            cameraGranted = granted
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            micGranted = granted
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let isGranted = cameraGranted && micGranted
            if !isGranted {
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "Camera and microphone access are needed for video features. Please enable them in settings.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                          UIApplication.shared.canOpenURL(settingsUrl) else { return }
                    UIApplication.shared.open(settingsUrl)
                }))
                self.present(alert, animated: true)
            }
            completion(isGranted)
        }
    }
}
