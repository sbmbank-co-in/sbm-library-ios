//
//  WebViewController.swift
//  sbm-library-ios
//
//  Created by Varun on 30/10/23.
//

import Foundation
import WebKit
import AVFoundation
import UIKit
import SwiftUI

public class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    private lazy var webView: WKWebView = {
        let webview = WKWebView()
        webview.navigationDelegate = self
        webview.uiDelegate = self
        webview.scrollView.isScrollEnabled = true
        return webview
    }()
    var urlString: String?
    
    public init(urlString: String?) {
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
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
        webView.frame = view.bounds
        
        
        
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                print("Cookie: \(cookie.name)=\(cookie.value)")
            }
        }
        
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        loadRequestWithCookies(completion: { error in
            if let error = error {
                print("Error loading webView: \(error)")
            }
        })
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        additionalSafeAreaInsets = UIEdgeInsets(top: -view.safeAreaInsets.top, left: 0, bottom: -view.safeAreaInsets.bottom, right: 0)
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
    
    //    func loadCookiesAndRequestIfNeeded() {
    //        let userDefaults = UserDefaults.standard
    //        let hasSyncedCookies = userDefaults.bool(forKey: "hasSyncedCookies")
    //
    //        if !hasSyncedCookies {
    //            webView.load(URLRequest(url: URL(string: "about:blank")!))
    //            synchronizeCookies {
    //                self.loadInitialRequest()
    //                userDefaults.set(true, forKey: "hasSyncedCookies")
    //            }
    //        } else {
    //            loadInitialRequest()
    //        }
    //    }
    
    //    func synchronizeCookies(completion: @escaping () -> Void) {
    //        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
    //        let cookies = HTTPCookieStorage.shared.cookies ?? []
    //        let dispatchGroup = DispatchGroup()
    //
    //        for cookie in cookies {
    //            dispatchGroup.enter()
    //            cookieStore.setCookie(cookie) {
    //                dispatchGroup.leave()
    //            }
    //        }
    //
    //        dispatchGroup.notify(queue: DispatchQueue.main) {
    //            completion()
    //        }
    //    }
    //
    //    func loadInitialRequest() {
    //        guard let urlString = urlString, let url = URL(string: urlString) else {
    //            print("Invalid URL")
    //            return
    //        }
    //        let request = URLRequest(url: url)
    //        webView.load(request)
    //    }
    
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
                print("isCameraActionRequired function not found on this page")
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
    
    enum InvalidURLError: Error {
        case invalidURL
    }
    
}
