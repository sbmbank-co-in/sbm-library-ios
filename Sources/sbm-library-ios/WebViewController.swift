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
import CoreLocation

public class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, CLLocationManagerDelegate {
    
    private lazy var webView: WKWebView = {
        let webConfiguration = WKWebViewConfiguration()
        
        webConfiguration.applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"
        
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
        if #available(iOS 15.0, *) {
            webView.configuration.mediaPlaybackRequiresUserAction = false
        }
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        if #available(iOS 14.0, *) {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        webView.customUserAgent = userAgent
        print("testing webview logs")
        return webView
    }()
    var urlString: String?
    var completion: (WebViewCallback) -> Void
    private var locationManager: CLLocationManager?
    private var locationGranted: Bool = false
    
    public init(urlString: String?, completion: @escaping (WebViewCallback) -> Void) {
        self.urlString = urlString
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
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
//    public func webView(_ webView: WKWebView, runOpenPanelWith parameters: Any, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
//       // requestCameraAndMicrophonePermission()
//        completionHandler(nil) // Proceed without opening file picker
//    }
    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        print("Media capture permission requested for type: \(type)")
        handleMediaPermission(type: type) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    // For iOS 14 and below
    public func webView(_ webView: WKWebView, didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if #available(iOS 15.0, *) {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Handle permissions for older iOS versions
        if let host = webView.url?.host {
            if host.contains("meet.") || host.contains("zoom.") {
                handleMediaPermission(type: "both") { _ in
                    completionHandler(.performDefaultHandling, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

    private func handleMediaPermission(type: Any, completion: @escaping (Bool) -> Void) {
        if #available(iOS 15.0, *) {
            let mediaType = type as! WKMediaCaptureType
            
            switch mediaType {
            case .cameraAndMicrophone:
                checkBothPermissions { cameraGranted, audioGranted in
                    completion(cameraGranted && audioGranted)
                }
            case .camera:
                handleCameraPermission(completion: completion)
            case .microphone:
                handleAudioPermission(completion: completion)
            @unknown default:
                completion(false)
            }
        }
    }

    private func checkBothPermissions(completion: @escaping (Bool, Bool) -> Void) {
        handleCameraPermission { cameraGranted in
            self.handleAudioPermission { audioGranted in
                completion(cameraGranted, audioGranted)
            }
        }
    }
    
    private func handleCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.showPermissionAlert(for: "Camera")
                        }
                        completion(granted)
                    }
                }
            case .restricted, .denied:
                DispatchQueue.main.async {
                    self.showPermissionAlert(for: "Camera")
                    completion(false)
                }
            case .authorized:
                completion(true)
            @unknown default:
                completion(false)
        }
    }

    private func handleAudioPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.showPermissionAlert(for: "Microphone")
                    }
                    completion(granted)
                }
            }
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.showPermissionAlert(for: "Microphone")
                completion(false)
            }
        case .authorized:
            completion(true)
        @unknown default:
            completion(false)
        }
    }

        // Handle navigation decisions
        public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let url = navigationResponse.response.url, url.absoluteString.contains("location") {
                print("requesting permission")
               // requestLocationPermission()
              //  requestCameraAndMicrophonePermission()
            }
            decisionHandler(.allow)
        }

      
    private func showPermissionAlert(for type: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "\(type) Access Required",
                message: "Please enable \(type) access in Settings to use this feature",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.present(alert, animated: true)
        }
    }



        // Handle location permission changes
        public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                locationGranted = true
            default:
                locationGranted = false
            }
        }
    
}


