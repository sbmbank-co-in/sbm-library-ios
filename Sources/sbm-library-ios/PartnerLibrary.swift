//
//  SBMLibrary.swift
//  sbm-library-ios
//
//  Created by Varun on 13/11/23.
//

import UIKit
import SwiftUI
import WebKit

@available(iOS 13.0, *)
@MainActor
public class PartnerLibrary {
    
    private let hostName: String
    private let deviceBindingEnabled: Bool
    var preloadedWebVC: WebViewController?
    var onMPINSetupSuccess: (() -> Void)?
    
    @MainActor public init(hostName: String, deviceBindingEnabled: Bool, whitelistedUrls: Array<String>, navigationBarDisabled: Bool) {
        self.hostName = hostName
        self.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.hostName = hostName
        EnvManager.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.whitelistedUrls = whitelistedUrls
        EnvManager.navigationBarDisabled = navigationBarDisabled
        
        Task {
            await preloadWebView()
        }
    }
    
    private func preloadWebView() async {
        // Create a WebViewController with a dummy preload URL or any required initial state.
        // Optionally, you can load a lightweight webpage or use the final URL later.
        let preloadURL = "\(EnvManager.hostName)"
        let webVC = WebViewController(urlString: preloadURL) { _ in
            // This callback can be empty since it’s just preloading.
            print("here")
        }
        // Trigger view loading so that the WebView begins loading content.
        _ = webVC.view
        
        // Propagate cookies from HTTPCookieStorage to WKWebView's cookie store.
        if let url = URL(string: preloadURL),
           let cookies = HTTPCookieStorage.shared.cookies(for: url),
           let wkWebView = webVC as? WKWebView {
            for cookie in cookies {
                try? await wkWebView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
        }
        
        self.preloadedWebVC = webVC
    }
    
    private func checkLogin() async throws -> NetworkResponse {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGGED_IN)!, method: "GET")
    }
    
    private func login(token: String) async throws -> NetworkResponse {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGIN)!, method: "POST", jsonPayload: ["token": token])
    }
    
    public func open(token: String, module: String, callback: @escaping @Sendable (WebViewCallback) -> Void) async throws {
        let checkLoginResponse = try await checkLogin()
        
        let coordinator = ViewTransitionCoordinator(viewController: findTopMostViewController())
        if checkLoginResponse.getString(forKey: "type") == "success" {
            if checkLoginResponse.getInt(forKey: "is_loggedin") == 1 {
                await coordinator.startProcess(module: module) { result in
                
                    print("here 72")
                    callback(result)
                
                }
            } else {
                _ = try await login(token: token)
                await coordinator.startProcess(module: module) { result in
                
                    print("here 79")
                    callback(result)
                
                }
            }
        } else {
            let _ = try await login(token: token)
            await coordinator.startProcess(module: module) { result in
            
                print("here 87")
                callback(result)
            }
        }
    }
    
    @MainActor private func findTopMostViewController() -> UIViewController {
        guard let window = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow }) else {
            fatalError("No active window found")
        }
        
        var topMostViewController = window.rootViewController
        while let presentedViewController = topMostViewController?.presentedViewController {
            topMostViewController = presentedViewController
        }
        return topMostViewController!
    }
    
    func checkDeviceBinding(bank: String) async throws -> Bool {
        if !deviceBindingEnabled {
            return false
        }
        
        let onboardingNext = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.BANKING_ONBOARDING_NEXT.dynamicParams(with: ["bank": bank]))!, method: "GET")
        
        if (onboardingNext.getString(forKey: "path") != nil && ((onboardingNext.getString(forKey: "path")!).contains("/onboarding/success")) || ((onboardingNext.getString(forKey: "path")!).contains("/onboarding/complete"))) {
            return true
        }
        
        return false
    }
    
    func bindDevice(on viewController: UIViewController, bank: String, partner: String, completion: @escaping @Sendable () -> Void) async {
        do {
            let toBindDevice = try await checkDeviceBinding(bank: bank)
            if toBindDevice {
                let isMPINSet = !(SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? "").isEmpty
                if isMPINSet {
                    await presentMPINSetup(on: viewController, partner: partner) {
                        Task { @MainActor in
                            completion()
                        }
                    }
                } else {
                    await presentDeviceBinding(on: viewController, bank: bank, partner: partner) {
                        Task { @MainActor in
                            completion()
                        }
                    }
                }
            } else {
                let parameters: [String: Any] = [
                    "device_uuid": UIDevice.current.identifierForVendor?.uuidString as Any,
                    "manufacturer": "Apple",
                    "model": UIDevice.modelName,
                    "os": "iOS",
                    "os_version": UIDevice.current.systemVersion,
                    "app_version": PackageInfo.version
                ]
                
                let response = try await NetworkManager.shared.makeRequest(
                    url: URL(string: ServiceNames.DEVICE_SESSION.dynamicParams(with: ["partner": partner]))!,
                    method: "POST",
                    jsonPayload: parameters
                )
                
                print("Bind device to session \(response)")
                
                await MainActor.run {
                    completion()
                }
            }
        } catch {
            print("Device binding error: \(error)")
            await MainActor.run {
                completion()
            }
        }
    }
    
    private func presentMPINSetup(on viewController: UIViewController, partner: String, completion: @escaping @Sendable () -> Void) async {
        let rootView = AnyView(MPINSetupViewWrapper(isMPINSet: true, partner: partner, onSuccess: {
            Task { @MainActor in
                completion()
            }
        }, onReset: {
            Task { @MainActor in
                await self.bindDevice(on: viewController, bank: partner, partner: partner, completion: completion)
            }
        }))
        
        await MainActor.run {
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.modalPresentationStyle = .fullScreen
            viewController.present(hostingController, animated: true)
        }
    }
    
    private func presentDeviceBinding(on viewController: UIViewController, bank: String, partner: String, completion: @escaping @Sendable () -> Void) async {
        let viewModel = DeviceBindingViewModel(bank: bank, partner: partner, onSuccess: {
            Task { @MainActor in
                completion()
            }
        }, onReset: {
            Task { @MainActor in
                await self.bindDevice(on: viewController, bank: bank, partner: partner, completion: completion)
            }
        })
        
        let rootView = AnyView(DeviceBindingWaitingView(viewModel: viewModel))
        
        await MainActor.run {
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.modalPresentationStyle = .fullScreen
            viewController.present(hostingController, animated: true)
        }
    }
}

@available(iOS 13.0, *)
@MainActor
class ViewTransitionCoordinator {
    private var viewController: UIViewController
    private var loaderViewController: LoaderViewController?
    private var library: PartnerLibrary
    
    init(viewController: UIViewController) {
        self.library = PartnerLibrarySingleton.shared.instance
        self.viewController = viewController
    }
    
    func startProcess(module: String, completion: @escaping @Sendable (WebViewCallback) -> Void) async {
        presentLoaderView()
        
        // Await device binding
        await bindDevice(module: module)
        
        // Then open the library; the callback is now executed on the MainActor, so you can safely call self.dismissLoaderView()
        await openLibrary(module: module) { callback in
            self.dismissLoaderView()
            completion(callback)
        }
    }
    
    private func presentLoaderView() {
        loaderViewController = LoaderViewController()
        loaderViewController?.modalPresentationStyle = .overFullScreen
        viewController.present(loaderViewController!, animated: true)
    }
    
    private func dismissLoaderView() {
        DispatchQueue.main.async {
            self.loaderViewController?.dismiss(animated: true) {
                self.loaderViewController = nil
            }
        }
    }
    
    private func bindDevice(module: String) async {
        var partner = ""
        var bank = ""
        if module.contains("banking") {
            if let bankingRange = module.range(of: "banking/") {
                let startIndex = bankingRange.upperBound
                if let endIndex = module[startIndex...].range(of: "/")?.lowerBound {
                    bank = String(module[startIndex..<endIndex])
                    partner = bank
                }
            }
        }
        await library.bindDevice(on: viewController, bank: bank, partner: partner) {
            // No extra code needed here, as we wait for completion automatically
        }
    }
    
    private func openLibrary(module: String, completion: @MainActor @escaping (WebViewCallback) -> Void) async {
        let webVC: WebViewController
        let newUrl = "\(EnvManager.hostName)\(module)"
        
        if let preloaded = library.preloadedWebVC {
            webVC = preloaded
            await MainActor.run {
            webVC.setCallback { result in
                print("here 271")
                completion(result)
            }
            }
            webVC.updateAndReload(with: newUrl)
        } else {
            webVC = WebViewController(urlString: newUrl) { result in
                print("here 276")
                completion(result)
            }
        }
        
        await presentWebViewController(webVC)
    }
    
    private func presentWebViewController(_ webVC: WebViewController) async {
        if let navigationController = viewController.navigationController {
            navigationController.pushViewController(webVC, animated: false)
            navigationController.setNavigationBarHidden(EnvManager.navigationBarDisabled, animated: false)
        } else {
            let navVC = UINavigationController(rootViewController: webVC)
            navVC.modalPresentationStyle = .fullScreen
            navVC.setNavigationBarHidden(EnvManager.navigationBarDisabled, animated: false)
            
            if let loaderVC = loaderViewController {
                loaderVC.present(navVC, animated: false)
            } else {
                viewController.present(navVC, animated: false)
            }
        }
    }
}

public enum LibraryError: Error {
    case hostnameNotSet
}
