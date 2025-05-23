//
//  WebViewController.swift
//  sbm-library-ios
//
//  Created by Varun on 30/10/23.
//

import AVFoundation
import CoreLocation
import Foundation
import SwiftUI
import UIKit
@preconcurrency import WebKit

@available(iOS 13.0, *)
public class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate,
    CLLocationManagerDelegate, UIGestureRecognizerDelegate
{

    public weak var originalViewController: UIViewController?
    private var config: [String: Any]?

    private lazy var webView: WKWebView = {
        let webConfiguration = WKWebViewConfiguration()
        let webViewConfig = config?["webview"] as? [String: Any] ?? [:]
        let settings = webViewConfig["settings"] as? [String: Any] ?? [:]

        webConfiguration.applicationNameForUserAgent =
            settings["applicationNameForUserAgent"] as? String ?? "Version/8.0.2 Safari/600.2.5"
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "iosListener")
        webConfiguration.userContentController = userContentController
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webConfiguration.preferences.javaScriptEnabled =
            settings["javaScriptEnabled"] as? Bool ?? true
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically =
            settings["javaScriptCanOpenWindowsAutomatically"] as? Bool ?? true
        webConfiguration.allowsInlineMediaPlayback =
            settings["allowsInlineMediaPlayback"] as? Bool ?? true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        if #available(iOS 15.0, *) {
            webConfiguration.mediaPlaybackRequiresUserAction =
                settings["mediaPlaybackRequiresUserAction"] as? Bool ?? false
        }
        webConfiguration.preferences.setValue(
            settings["allowFileAccessFromFileURLs"] as? Bool ?? true,
            forKey: "allowFileAccessFromFileURLs")
        if #available(iOS 14.0, *) {
            webConfiguration.defaultWebpagePreferences.allowsContentJavaScript =
                settings["allowsContentJavaScript"] as? Bool ?? true
        }
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = settings["scrollEnabled"] as? Bool ?? true
        webView.scrollView.maximumZoomScale = settings["maximumZoomScale"] as? CGFloat ?? 1.0
        webView.customUserAgent = settings["customUserAgent"] as? String ?? ""
        return webView
    }()
    var urlString: String?
    var completion: (WebViewCallback) -> Void
    private var locationManager: CLLocationManager?
    private var locationGranted: Bool = false

    public init(
        urlString: String?, originalViewController: UIViewController,
        completion: @escaping (WebViewCallback) -> Void, config: [String: Any]? = nil
    ) {
        self.urlString = urlString
        self.completion = completion
        self.originalViewController = originalViewController
        super.init(nibName: nil, bundle: nil)
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        self.config = config

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.tag = 1235
        view.backgroundColor = .white

        let swipeBackGesture = UIScreenEdgePanGestureRecognizer(
            target: self, action: #selector(handleSwipeBack(_:)))
        swipeBackGesture.edges = .left
        swipeBackGesture.delegate = self
        view.addGestureRecognizer(swipeBackGesture)

        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
        //        webView.frame = view.bounds

        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
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

    public var cookieStore: WKHTTPCookieStore {
        return webView.configuration.websiteDataStore.httpCookieStore
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //        additionalSafeAreaInsets = UIEdgeInsets(top: -view.safeAreaInsets.top, left: 0, bottom: -view.safeAreaInsets.bottom, right: 0)
    }

    @objc private func handleSwipeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized {
            if webView.canGoBack {
                webView.goBack()
            }
        }
    }

    // Implement UIGestureRecognizerDelegate method to allow simultaneous recognition
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    func loadRequestWithCookies(completion: @escaping (Error?) -> Void) {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let cookieStore = cookieStore

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

    public func webView(
        _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
    ) {
        print("WebView navigation failed: \(error)")
    }

    public func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    public func webView(
        _ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!
    ) {

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

@available(iOS 13.0, *)
extension WebViewController: WKScriptMessageHandler {
    public func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        if message.name == "spense_library" {
            if let messageBody = message.body as? String {
                print("Received message from web: \(messageBody)")
                // Handle the message or perform an action based on the message content
            }
        }
    }
}

@available(iOS 13.0, *)
extension WebViewController {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url?.absoluteString {
            AnalyticsLogger.logEvent([
                "event": "IOS_WEBVIEW_LOADED",
                "url": url,
            ])
        }
    }
}
@available(iOS 13.0, *)
extension WebViewController {
    public func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Convert your logic to Swift
        let urlString = url.absoluteString

        let webviewConfig = config?["webview"] as? [String: Any]
        let urlConfig = webviewConfig?["urlHandling"] as? [String: Any]
        let redirectPaths = urlConfig?["redirectPaths"] as? [String] ?? []
        print("redirectPaths: \(redirectPaths)")
        // 1. Handle redirect paths
        for path in redirectPaths {
            if urlString.contains(path) {
                print("paths: \(path)")
                if let status = url.query?.components(separatedBy: "=").last {
                    AnalyticsLogger.logEvent([
                        "event": "IOS_WEBVIEW_CALLBACK",
                        "status": status,
                        "url": urlString,
                    ])
                    completion(.redirect(status: status))
                }
                decisionHandler(.cancel)
                dismissWebView()
                return
            }
        }

        // 2. Handle file downloads
        if urlString.contains(".pdf") || urlString.lowercased().contains("/pdf")
            || urlString.contains("/download") || urlString.contains("/statements")
        {
            handleFileDownload(url: url, decisionHandler: decisionHandler)
            return
        }

        // 3. Whitelisted URLs
        for whitelistedUrl in EnvManager.whitelistedUrls {
            if urlString.contains(whitelistedUrl) || urlString.contains(EnvManager.hostName) {
                decisionHandler(.allow)
                return
            }
        }

        // 4. Open externally if not handled above
        openURLExternally(url) {
            AnalyticsLogger.logEvent([
                "event": "IOS_OPENING_URL_EXTERNALLY",
                "url": urlString,
            ])
            decisionHandler(.cancel)
        }
    }

    @available(iOS 15.0, *)
    public func webView(
        _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        print("Media capture permission requested for type: \(type)")
        handleMediaPermission(type: type) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    // For iOS 14 and below
    public func webView(
        _ webView: WKWebView,
        didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if #available(iOS 15.0, *) {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Handle permissions for older iOS versions
        if let host = webView.url?.host {
            if host.contains("sbmkyc")  // ||host.contains(".")
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
    private func handleMediaPermission(
        type: WKMediaCaptureType, completion: @escaping (Bool) -> Void
    ) {
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

    private func showPermissionAlert(for type: String) {
        let alert = UIAlertController(
            title: "\(type) Access Required",
            message: "Please enable \(type) access in Settings to use this feature",
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }

    // Handle location permission changes
    public func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationGranted = true
        default:
            locationGranted = false
        }
    }
    func dismissWebView(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController {
            if let originalVC = originalViewController {
                if navigationController.viewControllers.contains(where: { $0 === originalVC }) {
                    debugPrint("Original VC found in navigation stack, popping to it")
                    completion?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigationController.popToViewController(originalVC, animated: animated)
                    }
                } else {
                    debugPrint("Original VC not in navigation stack")
                }
            } else {
                debugPrint("dismissing ")
                completion?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationController.popViewController(animated: true)
                }
            }
        } else {
            debugPrint("No navigation controller, dismissing modally")
            self.dismiss(animated: animated, completion: completion)
        }
    }
    private func handleFileDownload(
        url: URL, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {

        let session = URLSession.shared
        let task = session.downloadTask(with: url) { (tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                // Generate a unique file name in the cache directory
                if let cachesDirectory = FileManager.default.urls(
                    for: .cachesDirectory, in: .userDomainMask
                ).first {
                    let fileName = response?.suggestedFilename ?? url.lastPathComponent
                    let destinationUrl = cachesDirectory.appendingPathComponent(fileName)

                    do {
                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: destinationUrl.path) {
                            try FileManager.default.removeItem(at: destinationUrl)
                        }

                        // Copy downloaded file to destination
                        try FileManager.default.copyItem(at: tempLocalUrl, to: destinationUrl)

                        DispatchQueue.main.async {
                            // Open the file using system default handler
                            let documentController = UIDocumentInteractionController(
                                url: destinationUrl)
                            documentController.delegate = self
                            documentController.presentPreview(animated: true)
                        }
                    } catch {
                        print("Error handling file: \(error)")
                    }
                }
            }
        }
        task.resume()
        decisionHandler(.cancel)
    }

}
@available(iOS 13.0, *)
extension WebViewController: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        return self
    }
}
