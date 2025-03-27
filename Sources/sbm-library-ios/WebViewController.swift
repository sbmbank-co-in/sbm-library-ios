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
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webConfiguration.preferences.javaScriptEnabled = true
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        if #available(iOS 15.0, *) {
            webConfiguration.mediaPlaybackRequiresUserAction = false
        }
        webConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        if #available(iOS 14.0, *) {
            webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        return webView
    }()
    var urlString: String?
    var completion: (WebViewCallback) -> Void
    private var locationManager: CLLocationManager?
    private var locationGranted: Bool = false
    private var deeplinkScreenMap: [String: String] = [:]
    public func setDeeplinkScreenMap(_ map: [String: String]) {
        deeplinkScreenMap = map
    }
    
    public func getDeeplinkScreenMap() -> [String: String] {
        return deeplinkScreenMap
    }
    
    public init(urlString: String?, completion: @escaping (WebViewCallback) -> Void, deeplinkScreenMap: [String: String] = [:]) {
        self.urlString = urlString
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        self.deeplinkScreenMap = deeplinkScreenMap
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.restorationIdentifier = "2222"
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
                debugPrint("Error loading webView: \(error)")
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
                debugPrint("Error reloading WebView: \(error)")
            }
        }
    }
    
    public func setCallback(_ callback: @escaping (WebViewCallback) -> Void) {
        self.completion = callback
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        debugPrint("WebView navigation failed: \(error)")
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
                debugPrint("Received message from web: \(messageBody)")
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
        
        debugPrint(urlString)
        
        if urlString.contains("api/user/redirect?status=") {
            if let status = url.query?.components(separatedBy: "=").last {
                // Call the onRedirect callback and pass the status
                completion(.redirect(status: status))
            }
            decisionHandler(.cancel) // Stop loading since we're handling it
          //  dismissWebView()
            self.dismiss(animated: true)
            return
        }
        if url.absoluteString.contains("api/user/redirect") {
            let status = url.lastPathComponent
            completion(.redirect(status: status))
            decisionHandler(.cancel) // Stop loading since we're handling it
           // dismissWebView()
            self.dismiss(animated: true)
            return
        }
        
        if urlString.contains("session-expired") {
            completion(.logout)
            decisionHandler(.cancel) // Stop loading
           // dismissWebView()
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
        
        if tryDeepLink(url) {
            decisionHandler(.cancel)
        } else {
            debugPrint("Deep link failed, opening externally")
            handleExternalURL(url)
            decisionHandler(.cancel)
        }
    }
    
    private func tryDeepLink(_ url: URL) -> Bool {
        debugPrint("🔍 Processing URL: \(url.absoluteString)")
        
        guard let navigationController = self.navigationController else {
            debugPrint("no navigation controller available")
            return false
        }
        
        // First check if any app can handle this URL (including our own app)
        if UIApplication.shared.canOpenURL(url) {
            if let scheme = url.scheme {
                return handleInternalNavigation(url, with: navigationController)
                
                handleExternalURL(url)
                return true
            }
        }
        return false
    }
    
    private func handleInternalNavigation(_ url: URL, with navigationController: UINavigationController) -> Bool {
        guard let host = url.host else {
            debugPrint("no host in URL")
            return false
        }
        
        //               debugPrint("deeplinkScreenMap is ", deeplinkScreenMap)
        
        
        if let viewControllerName = deeplinkScreenMap[host] {
            let appBundle = Bundle.main
            
            // Get the module name (usually your app's name)
            if let moduleName = appBundle.infoDictionary?["CFBundleName"] as? String,
               let viewControllerClass = NSClassFromString("\(moduleName).\(viewControllerName)") as? UIViewController.Type {
                
                let viewController = viewControllerClass.init()
                
                
                debugPrint("Pushing view controller: \(viewControllerName)")
                navigationController.pushViewController(viewController, animated: true)
                return true
            }
        }
        
        
        debugPrint("no matching view controller found, handling externally")
        handleExternalURL(url)
        return true
    }
    
    private func handleExternalURL(_ url: URL) {
        debugPrint("opening URL externally: \(url)")
        UIApplication.shared.open(url, options: [:]) { success in
            debugPrint(success ? "Successfully opened URL" : "Failed to open URL")
        }
    }
    
    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        debugPrint("Media capture permission requested for type: \(type)")
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
            if host.contains("sbmkyc")
            // ||host.contains(".")
            {
                // Handle media permission for older iOS versions
                handleMediaPermissionForOlderVersions { _ in
                    completionHandler(.performDefaultHandling, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
    private func handleMediaPermissionForOlderVersions(completion: @escaping (Bool) -> Void) {
        checkBothPermissions { cameraGranted, audioGranted in
            completion(cameraGranted && audioGranted)
        }
    }
    @available(iOS 15.0, *)
    private func handleMediaPermission(type: WKMediaCaptureType, completion: @escaping (Bool) -> Void) {
        switch type {
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
    //        public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    //            if let url = navigationResponse.response.url, url.absoluteString.contains("location") {
    //                debugPrint("requesting permission")
    //               // requestLocationPermission()
    //              //  requestCameraAndMicrophonePermission()
    //            }
    //            decisionHandler(.allow)
    //        }
    
    
    private func showPermissionAlert(for type: String) {
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
    
    
    
    
    // Handle location permission changes
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationGranted = true
        default:
            locationGranted = false
        }
    }
    func dismissWebView(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController {
            // Check if this is the last view controller in stack
            if navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: animated)
                completion?()
            } else {
                // If it's the only view controller, dismiss the whole navigation stack
                navigationController.dismiss(animated: animated, completion: completion)
            }
        } else {
            // If there's no navigation controller, just dismiss
            self.dismiss(animated: animated, completion: completion)
        }
    }
    
}


