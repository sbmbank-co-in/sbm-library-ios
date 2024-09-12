//
//  SBMLibrary.swift
//  sbm-library-ios
//
//  Created by Varun on 13/11/23.
//

import UIKit
import SwiftUI

@available(iOS 13.0, *)
public class PartnerLibrary {
    
    private var hostName = EnvManager.hostName
    private var deviceBindingEnabled = EnvManager.deviceBindingEnabled
    var onMPINSetupSuccess: (() -> Void)?
    
    init(hostName: String, deviceBindingEnabled: Bool, whitelistedUrls: Array<String>) {
        self.hostName = hostName
        self.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.hostName = hostName
        EnvManager.deviceBindingEnabled = deviceBindingEnabled
        EnvManager.whitelistedUrls = whitelistedUrls
    }
    
    private func checkLogin() async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGGED_IN)!, method: "GET")
    }
    
    private func login(token: String) async throws -> [String: Any] {
        return try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.LOGIN)!, method: "POST", jsonPayload: ["token": token])
    }
    
    public func open(token: String, module: String, callback callback: @escaping (WebViewCallback) -> Void) async throws {
        let checkLoginResponse = try await checkLogin()
        print(checkLoginResponse)
        if checkLoginResponse["type"] as! String == "success" {
            if checkLoginResponse["is_loggedin"] as! Int == 1 {
                DispatchQueue.main.async {
                    let viewTransitionCoordinator = ViewTransitionCoordinator(viewController: self.findTopMostViewController())
                    viewTransitionCoordinator.startProcess(module: module, completion: callback)
                }
            } else {
                try await login(token: token)
                DispatchQueue.main.async {
                    let viewTransitionCoordinator = ViewTransitionCoordinator(viewController: self.findTopMostViewController())
                    viewTransitionCoordinator.startProcess(module: module, completion: callback)
                }
            }
        }
    }
    
    private func findTopMostViewController() -> UIViewController {
        //        var topMostViewController = UIApplication.shared.windows.first?.rootViewController
        //        while let presentedViewController = topMostViewController?.presentedViewController {
        //            topMostViewController = presentedViewController
        //        }
        //        return topMostViewController!
        guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
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
        
        if (onboardingNext["path"] != nil && ((onboardingNext["path"] as! String).contains("/onboarding/success")) || ((onboardingNext["path"] as! String).contains("/onboarding/complete"))) {
            return true
        }
        
        return false
    }
    
    func bindDevice(on viewController: UIViewController, bank: String, partner: String, completion: @escaping () -> Void) {
        Task {
            do {
                let toBindDevice = try await self.checkDeviceBinding(bank: bank)
                if (toBindDevice) {
                    let isMPINSet = !(SharedPreferenceManager.shared.getValue(forKey: "MPIN") ?? "").isEmpty
                    print("isMPINSet \(isMPINSet)")
                    if (isMPINSet) {
                        let rootView = AnyView(MPINSetupViewWrapper(isMPINSet: true, partner: partner, onSuccess: {
                            Task {
                                await MainActor.run {
                                    viewController.dismiss(animated: true, completion: completion)
                                }
                            }
                        }, onReset: {
                            self.bindDevice(on: viewController, bank: bank, partner: partner, completion: completion)
                        }))
                        await MainActor.run {
                            let hostingController = UIHostingController(rootView: rootView)
                            hostingController.modalPresentationStyle = .fullScreen
                            viewController.present(hostingController, animated: true, completion: nil)
                        }
                    } else {
                        let viewModel = DeviceBindingViewModel(bank: bank, partner: partner, onSuccess: {
                            Task {
                                await MainActor.run {
                                    viewController.dismiss(animated: true, completion: completion)
                                }
                            }
                        }, onReset: {
                            self.bindDevice(on: viewController, bank: bank, partner: partner, completion: completion)
                        })
                        let rootView = AnyView(DeviceBindingWaitingView(viewModel: viewModel))
                        await MainActor.run {
                            let hostingController = UIHostingController(rootView: rootView)
                            hostingController.modalPresentationStyle = .fullScreen
                            viewController.present(hostingController, animated: true, completion: nil)
                        }
                    }
                } else {
                    let parameters = await ["device_uuid": UIDevice.current.identifierForVendor?.uuidString, "manufacturer": "Apple", "model": UIDevice.modelName, "os": "iOS", "os_version": UIDevice.current.systemVersion, "app_version": PackageInfo.version] as [String : Any]
                    print(parameters)
                    let response = try await NetworkManager.shared.makeRequest(url: URL(string: ServiceNames.DEVICE_SESSION.dynamicParams(with: ["partner": partner]))!, method: "POST", jsonPayload: parameters)
                    if response["code"] as? String == "DEVICE_BINDED_SESSION_FAILURE" {
                        print(response)
                        await MainActor.run {
                            viewController.dismiss(animated: true, completion: completion)
                        }
                    } else {
                        await MainActor.run {
                            viewController.dismiss(animated: true, completion: completion)
                        }
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    func openWebView(on viewController: UIViewController, withSlug slug: String, completion callback: @escaping (WebViewCallback) -> Void) {
        //        let webVC = WebViewController(urlString: "\(EnvManager.hostName)\(slug)", completion: completion)
        //        let navVC = UINavigationController(rootViewController: webVC)
        //        navVC.modalPresentationStyle = .fullScreen
        //        viewController.present(navVC, animated: true, completion: nil)
        let webVC = WebViewController(urlString: "\(EnvManager.hostName)\(slug)", completion: callback)
        if let navController = viewController.navigationController {
            navController.pushViewController(webVC, animated: true)  // Use push if inside a navigation controller
        } else {
            let navVC = UINavigationController(rootViewController: webVC)
            navVC.modalPresentationStyle = .fullScreen
            viewController.present(navVC, animated: true, completion: nil)
        }
    }
    
    public func getViewController(withSlug slug: String, completion: @escaping (WebViewCallback) -> Void) -> UINavigationController {
        let webVC = WebViewController(urlString: "\(EnvManager.hostName)\(slug)", completion: completion)
        let navVC = UINavigationController(rootViewController: webVC)
        navVC.modalPresentationStyle = .fullScreen
        return navVC
    }
}

@available(iOS 13.0, *)
class ViewTransitionCoordinator {
    private var viewController: UIViewController
    private var loaderViewController: LoaderViewController?
    private let library = PartnerLibrarySingleton.shared.instance
    
    init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    func startProcess(module: String, completion: @escaping (WebViewCallback) -> Void) {
        presentLoaderView()
        bindDevice(module: module, completion: completion)
    }
    
    private func presentLoaderView() {
        loaderViewController = LoaderViewController()
        loaderViewController?.modalPresentationStyle = .overFullScreen
        viewController.present(loaderViewController!, animated: true, completion: nil)
    }
    
    private func dismissLoaderView() {
        loaderViewController?.dismiss(animated: true, completion: nil)
    }
    
    private func bindDevice(module: String, completion: @escaping (WebViewCallback) -> Void) {
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
        self.library.bindDevice(on: loaderViewController!, bank: bank, partner: partner) {
            self.loaderViewController?.dismiss(animated: true) {
                self.openLibrary(module: module, completion: completion)
            }
        }
    }
    
    private func openLibrary(module: String, completion: @escaping (WebViewCallback) -> Void) {
        self.library.openWebView(on: viewController, withSlug: module, completion: completion)
        dismissLoaderView()
    }
}

public enum LibraryError: Error {
    case hostnameNotSet
}
